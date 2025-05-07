# frozen_string_literal: true

module TbService
  class RegimenEngine
    include ModelUtils
    include TimeUtils

    def initialize(program:, date: Date.today)
      @program = program
      @date = date
    end

    def get_tb_regimen_group(person, group)
      patient = Patient.find_by(patient_id: person)
      case group
      when 'first-line'
        first_line_drugs(patient:)
      when 'second-line'
        second_line_drugs(patient:)
      when 'second-line-concepts'
        second_line_concepts
      when 'current-regimen'
        find_regimens(patient: person)
      when 'secondline-supplements'
        secondline_supplements(patient:)
      end
    end

    def secondline_supplements(patient:)
      NtpRegimen.adjust_weight_band(
        Drug.get_drug_group('Secondline supplements'),
        patient.weight.floor
      )
    end

    def first_line_drugs(patient:)
      NtpRegimen.adjust_weight_band(
        Drug.get_drug_group('First-line tuberculosis drugs'),
        patient.weight.floor
      )
    end

    def second_line_drugs(patient:)
      NtpRegimen.adjust_weight_band(
        Drug.get_drug_group('Second line TB drugs'),
        patient.weight.floor
      )
    end

    def second_line_concepts
      Drug.get_drug_group_concepts('Second line TB drugs')
    end

    def meningitis_tb?(patient:)
      classification = concept('Tuberculosis classification')
      meningitis_tb_concept = concept('Meningitis Tuberculosis')
      Observation.where(concept: classification,
                        answer_concept: meningitis_tb_concept,
                        person: patient.patient_id)\
                 .exists?
    end

    def is_eligible_for_ipt?(person:)
      return false if TimeUtils.get_person_age(birthdate: person.birthdate) > 5

      currently_tb_negative?(person:)
    end

    # retrieve the most recent Negative TB status
    def currently_tb_negative?(person:)
      tb_status = concept('TB status')
      negative = concept('Negative')
      status = Observation.where(
        'person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= DATE(?)',
        person.person_id, tb_status.concept_id, @date
      ).order(obs_datetime: :desc).first
      begin
        (status.value_coded == negative.concept_id)
      rescue StandardError
        false
      end
    end

    def tb_hiv_present?(patient:)
      tb_positive?(patient:) && Observation.where(person: patient.person,
                                                  concept: concept('HIV Status'),
                                                  value_coded: concept('Positive').concept_id).exists?
    end

    def tb_positive?(patient:)
      Observation.where(person: patient.person,
                        concept: concept('TB Status'),
                        value_coded: concept('Positive').concept_id).exists? && !cured?(patient:)
    end

    def cured?(patient:)
      cured_state_id = 97
      PatientState.joins(:patient_program)\
                  .where('patient_program.program_id = ? AND patient_program.patient_id = ? AND state = ? AND end_date = null',
                         @program.program_id,
                         patient.patient_id,
                         cured_state_id).exists?
    end

    def pregnant?(patient:)
      Observation.where('person_id = ? AND concept_id = ? AND value_coded = ? AND obs_datetime >= ?',
                        patient.person.person_id,
                        concept('Patient Pregnant').concept_id,
                        concept('Yes').concept_id,
                        9.months.ago).exists?
    end

    def ipt_drug(weight:)
      drug = drug('INH or H (Isoniazid 100mg tablet)')
      drug = drug('INH or H (Isoniazid 300mg tablet)') if weight > 25
      remap_ipt_drug_to_regimen(ipt_drug: drug)
    end

    def remap_ipt_drug_to_regimen(ipt_drug:)
      [{
        am_dose: 1,
        noon_dose: 0,
        pm_dose: 0,
        drug: ipt_drug,
        id: ipt_drug['drug_id']
      }]
    end

    def custom_regimen_ingredients(patient:)
      NtpRegimen.joins(:drug).where(
        '? BETWEEN min_weight AND max_weight',
        patient.weight.floor
      )
    end

    def find_regimens(patient:)
      mdr = mdr_service(patient:)

      patient = patient[:patient] if patient.is_a? Hash

      return mdr.get_current_regimen_drugs if mdr.patient_on_mdr_treatment?

      return ipt_drug(weight: patient.weight) if is_eligible_for_ipt?(person: patient.person)

      if averse_to_strepto?(patient)
        return first_line_drugs(patient:).reject do |regimen|
                 regimen.drug.name[/Streptomycin/]
               end
      end

      unless tb_hiv_present?(patient:)
        return first_line_drugs(patient:).reject do |regimen|
                 regimen.drug.name == 'Rifabutin Isoniazid Pyrazinamide Ethambutol'
               end
      end

      first_line_drugs(patient:)
    end

    def find_regimens_by_patient(patient:)
      find_regimens(patient:)
    end

    def averse_to_strepto?(patient)
      !meningitis_tb?(patient:) || pregnant?(patient:)
    end

    def mdr_service(patient:)
      TbService::TbMdrService.new(patient, @program, Time.now)
    end
  end
end
