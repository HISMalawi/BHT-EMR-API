# frozen_string_literal: true

require 'set'

module TBService
  class RegimenEngine
    include ModelUtils
    include TimeUtils

    def initialize(program:)
      @program = program
    end

    def first_line_drugs (patient:)
      drug_set = Drug.first_line_tb_drugs().map(&:drug_id)
      drug_placeholders = '(' + (['?'] * drug_set.size).join(', ')
      NtpRegimen.joins(:drug).where(
        "? BETWEEN CAST(min_weight AS DECIMAL(4, 1)) AND CAST(max_weight AS DECIMAL(4, 1))) AND ntp_regimens.drug_id IN #{drug_placeholders}",
        patient.weight.to_f.round(1),
        *drug_set
      )
    end

    def second_line_drugs (patient:)
      drug_set = Drug.second_line_tb_drugs().map(&:drug_id)
      drug_placeholders = '(' + (['?'] * drug_set.size).join(', ') + ')'
      NtpRegimen.joins(:drug).where(
        "? BETWEEN CAST(min_weight AS DECIMAL(4, 1)) AND CAST(max_weight AS DECIMAL(4, 1)) AND ntp_regimens.drug_id IN #{drug_placeholders}",
        patient.weight.to_f.round(1),
        *drug_set
      )
    end

    def has_mdr_tb? (patient:)
      mdr_tb_state_id = 99
      PatientState.joins(:patient_program)\
                  .where('patient_program.program_id = ? AND patient_program.patient_id = ? AND state = ? AND end_date is null',
                         @program.program_id,
                         patient.patient_id,
                         mdr_tb_state_id).exists?
    end

    def meningitis_tb_absent? (patient:)
      classification = concept('Tuberculosis')
      meningitis_tb_concept = concept('Meningitis Tuberculosis')
      return true if Observation.where('concept_id = ? AND value_coded = ? AND person_id = ?',
                                     classification.concept_id,
                                     meningitis_tb_concept.concept_id,
                                     patient.patient_id).blank?

      cured(patient: patient)
    end

    def is_eligible_for_ipt?(person:)
      return false if TimeUtils.get_person_age(birthdate: person.birthdate) > 5
      currently_tb_negative?(person: person)
    end

    # retrieve the most recent Negative TB status
    def currently_tb_negative?(person:)
      tb_status = concept('TB status')
      negative = concept('Negative')
      status = Observation.where(
        'person_id = ? AND concept_id = ?',
        person.person_id, tb_status.concept_id
      ).order(obs_datetime: :desc).first
      begin
        (status.value_coded == negative.concept_id)
      rescue StandardError
        false
      end
    end

    def tb_hiv_present? (patient:)
      tb_positive(patient: patient) && Observation.where(person: patient.person,
                                                         concept: concept('HIV Status'),
                                                         value_coded: concept('Positive').concept_id).exists?
    end

    def tb_positive? (patient:)
      Observation.where(person: patient.person,
                        concept: concept('TB Status'),
                        value_coded: concept('Positive').concept_id).exists? && !cured?(patient: patient)
    end

    def cured? (patient:)
      cured_state_id = 97
      PatientState.joins(:patient_program)\
                  .where('patient_program.program_id = ? AND patient_program.patient_id = ? AND state = ? AND end_date = null',
                         @program.program_id,
                         @patient.patient_id,
                         cured_state).exists?
    end

    def pregnant? (patient:)
      Observation.where('person_id = ? AND concept_id = ? AND value_coded = ? AND obs_datetime >= ?',
                        patient.person.person_id,
                        concept('Patient Pregnant').concept_id,
                        concept('Yes').concept_id,
                        9.months.ago).exists?
    end

    def ipt_drug (weight:)
      drug = drug('INH or H (Isoniazid 100mg tablet)')
      drug = drug('INH or H (Isoniazid 300mg tablet)') if weight > 25
      remap_ipt_drug_to_regimen(ipt_drug: drug)
    end

    def remap_ipt_drug_to_regimen (ipt_drug:)
      [{
        am_dose: 1,
        noon_dose: 0,
        pm_dose: 0,
        drug: ipt_drug,
        id: ipt_drug['drug_id']
      }]
    end

    def custom_regimen_ingredients (patient:)
      NtpRegimen.joins(:drug).where(
        "? BETWEEN CAST(min_weight AS DECIMAL(4, 1)) AND CAST(max_weight AS DECIMAL(4, 1))",
        patient.weight.to_f.round(1)
      )
    end

    def find_regimens(patient)
      return second_line_drugs(patient: patient) if has_mdr_tb?(patient: patient)

      return ipt_drug(weight: patient.weight) if is_eligible_for_ipt?(person: patient.person)

      return first_line_drugs(patient: patient).select { |regimen| regimen.drug.name != 'Streptomycin' } if (meningitis_tb_absent?(patient: patient) || pregnant?(patient: patient))

      return first_line_drugs(patient: patient).select { |regimen| regimen.drug.name != 'Rifabutin Isoniazid Pyrazinamide Ethambutol' } unless tb_hiv_present?(patient: patient)

      first_line_drugs(patient: patient)
    end
  end
end