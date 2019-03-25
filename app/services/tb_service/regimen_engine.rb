# frozen_string_literal: true

require 'set'

module TBService
  class RegimenEngine
    include ModelUtils

    def initialize(program:)
      @program = program
    end

    def patient_state_service
      PatientStateService.new
    end

    def program_work_flow_state #might remove this
      ProgramWorkflowState.new
    end 

    def custom_regimen_ingredients
      #('Rifampicin isoniazid and pyrazinamide'), concept('Ethambutol'), concept('Rifampicin and isoniazid'), concept('Rifampicin Isoniazid Pyrazinamide Ethambutol')
      tb_extra_concepts = Concept.joins(:concept_names).where(concept_name: { name: %w[Isoniazid Rifampicin Pyrazinamide Ethambutol] } )
      drugs = Drug.where(concept: tb_extra_concepts)
      drugs
		end
		
		#NEED TO CHECK WHICH PATIENT ENCOUNTER OF PRESCRIPTION
		#OBERVATION IF ON INTENSIVE OR CONTINOUS PHASE
		#regimes based onw weight
    def find_regimens(patient, pellets: false)
        regimens = NtpRegimen.where(
          '(CAST(min_weight AS DECIMAL(4, 1)) <= :weight
           AND CAST(max_weight AS DECIMAL(4, 1)) >= :weight)',
          weight: patient.weight.to_f.round(1)
        )
        regimens
    end

    def find_all_patient_states(program, patient, ref_date)
      all_states = patient_state_service.all_patient_states(program, patient, ref_date)
    end

    
    #prescribe drug is saved as an observation to the database
    # Returns dosages for patients prescribed ARVs
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

      # Isoniazid(H) Rifampicin (R) Pyrazinamide (P) Ethambutol (E)
      #RHZ 75/50/150, E 100, RH 75/50, RHZE - R150 H75 Z400 E275, RH - R150 H75
      tb_extras_concepts = [concept('Rifampicin isoniazid and pyrazinamide'), concept('Ethambutol'), concept('Rifampicin and isoniazid'), concept('Rifampicin Isoniazid Pyrazinamide Ethambutol')] #add TB concepts

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


  end
end
