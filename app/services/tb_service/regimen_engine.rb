# frozen_string_literal: true

require 'set'

module TBService
  class RegimenEngine
    include ModelUtils
    include TimeUtils

    def initialize(program:)
      @program = program
    end

    def is_eligible_for_ipt? (person:)
      return false if TimeUtils.get_person_age(birthdate: person.birthdate) > 5
      person_is_tb_negative?(person: person)
    end

    def person_is_tb_negative? (person:)
      Observation.where(person: person,
        concept: concept('TB Status'),
        value_coded: concept('Negative').concept_id).exists?
    end

    def find_ipt_drug (weight:)
      drug = drug('INH or H (Isoniazid 100mg tablet)')
      drug = drug('INH or H (Isoniazid 300mg tablet)') if weight > 25
      remap_ipt_drug_to_regimen(ipt_drug: drug)
    end

    def remap_ipt_drug_to_regimen (ipt_drug:)
      [{
        am_dose: 1,
        noon_dose: 0,
        pm_dose: 0,
        drug: ipt_drug
      }]
    end

    def patient_state_service
      PatientStateService.new
    end

    def program_work_flow_state #might remove this
      ProgramWorkflowState.new
    end

    def custom_regimen_ingredients
      tb_extra_concepts = Concept.joins(:concept_names).where(concept_name: { name: %w[Isoniazid Rifampicin Pyrazinamide Ethambutol] } )
      drugs = Drug.where(concept: tb_extra_concepts)
      drugs
    end

		#NEED TO CHECK WHICH PATIENT ENCOUNTER OF PRESCRIPTION
		#OBERVATION IF ON INTENSIVE OR CONTINOUS PHASE
		#regimes based onw weight
    def find_regimens(patient, pellets: false)
      return find_ipt_drug(weight: patient.weight) if is_eligible_for_ipt?(person: patient.person)

      tb_meningitis_drug_concept = concept 'Rifampcin Isoniazed Pyrazanamide Ethambutol and Streptomycin'

      drug = Drug.find_by(concept_id: tb_meningitis_drug_concept.concept_id)
      if (patient_not_cured_with_tb_meningitis?(patient, Time.now)) #Temprailty Time.now
        NtpRegimen.where(
          '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
          weight: patient.weight.to_f.round(1)
        )
       else
        NtpRegimen.where(
          '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight) AND drug_id != :drug_id',
          weight: patient.weight.to_f.round(1),drug_id: drug.drug_id
        )
       end
    end

    def find_all_patient_states(program, patient, ref_date)
      all_states = patient_state_service.all_patient_states(program, patient, ref_date)
    end


    #prescribe drug is saved as an observation to the database
    # Returns dosages for patients prescribed TB drugs
    def find_dosages(patient, date = Date.today)
      # TODO: Refactor this into smaller functions

      # Make sure it has been stated explicitly that drug are getting prescribed
      # to this patient
      prescribe_drugs = Observation.where(person_id: patient.patient_id,
                                          concept: concept('Prescribe drugs'),
                                          value_coded: concept('Yes').concept_id)\
                                   .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date))
                                   .order(obs_datetime: :desc)
                                   .first

      return {} unless prescribe_drugs

      tb_extras_concepts = [concept('Rifampicin isoniazid and pyrazinamide'), concept('Ethambutol'), concept('Rifampicin and isoniazid'), concept('Rifampicin Isoniazid Pyrazinamide Ethambutol'), concept('Rifampcin Isoniazed Pyrazanamide Ethambutol and Streptomycin')] #add TB concepts

      orders = Observation.where(concept: concept('Medication orders'),
                                 person: patient.person)
                          .where('obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(date)) #orders

      orders.each_with_object({}) do |order, dosages|
        next unless order.value_coded # Raise a warning here

        drug_concept = Concept.find_by(concept_id: order.value_coded)
        unless drug_concept
          Rails.logger.warn "Couldn't find drug concept using value_coded ##{order.value_coded} of order ##{order.order_id}"
          next
        end

        next unless tb_extras_concepts.include?(drug_concept)


        drugs = Drug.where(concept: drug_concept)



        ingredients = NtpRegimen.where(drug: drugs)\
                                          .where('CAST(min_weight AS DECIMAL(4, 1)) <= :weight
                                                  AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight',
                                                 weight: patient.weight.to_f.round(1))
        ingredients

        ingredients.each do |ingredient|
          dosages[ingredient.drug.concept.concept_names.first.name] = ingredient
        end
      end
    end

    #patient has tb meningitis and is not cured
    def patient_not_cured_with_tb_meningitis?(patient, date)
      tb_type = concept 'Tuberculosis classification'
      yes_concept = concept 'Meningitis tuberculosis'
      has_tb_meningitis = Observation.where(
        "person_id = ? AND concept_id = ? AND value_coded = ?",
        patient.patient_id, tb_type.concept_id, yes_concept.concept_id
      ).order(obs_datetime: :desc).first.present?

      treatment_complete = concept 'Treatment complete'
      current_outcome = patient_summary(Patient.find(patient.patient_id), date).current_outcome

      begin
        ((current_outcome.concept_id != treatment_complete.concept_id) && has_tb_meningitis)
      rescue
        false
      end

    end

    private
    def patient_summary(patient, date)
      TBService::PatientSummary.new patient, date
    end

  end
end



