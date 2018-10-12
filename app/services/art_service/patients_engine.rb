# frozen_string_literal: true

module ARTService
  # Patients sub service.
  #
  # Basically provides ART specific patient-centric functionality
  class PatientsEngine
    def initialize(program:)
      @program = program
    end

    # Retrieves given patient's status info.
    #
    # The info is just what you would get on a patient information
    # confirmation page in an ART application.
    def patient(patient_id)
      summarise_patient Patient.find(patient_id)
    end

    def patient_last_drugs_received(patient_id, ref_date: nil)
      ref_date = ref_date ? Date.strptime(ref_date) : Date.today

      dispensing_encounter = Encounter.joins(:type).where(
        'encounter_type.name = ? AND encounter.patient_id = ?
         AND DATE(encounter_datetime) <= DATE(?)',
        'DISPENSING', patient_id, ref_date
      ).order(encounter_datetime: :desc).first

      return [] unless dispensing_encounter

      dispensing_encounter.observations.each_with_object([]) do |obs, drugs|
        next unless obs.value_drug

        order = obs.order
        next unless order.drug_order

        drugs << order.drug_order if order.drug_order.drug.arv?
      end
    end

    def all_patients(paginator: nil)
      # TODO: Retrieve all patients
      []
    end

    private

    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'
    FILING_NUMBER = 'Filing number'

    SECONDS_IN_MONTH = 2592000

    include ModelUtils

    def summarise_patient(patient)
      art_start_date, art_duration = patient_art_period(patient)
      {
        patient_id: patient.patient_id,
        npid: patient_identifier(patient, NPID_TYPE),
        arv_number: patient_identifier(patient, ARV_NO_TYPE),
        filing_number: patient_identifier(patient, FILING_NUMBER),
        current_outcome: patient_current_outcome(patient),
        residence: patient_residence(patient),
        art_duration: art_duration,
        current_regimen: patient_current_regimen(patient),
        art_start_date: art_start_date,
        reason_for_art: patient_art_reason(patient)
      }
    end

    def patient_identifier(patient, identifier_type_name)
      identifier_type = PatientIdentifierType.find_by_name(identifier_type_name)
      return 'UNKNOWN' unless identifier_type
      identifiers = patient.patient_identifiers.where(
        identifier_type: identifier_type.patient_identifier_type_id
      )
      identifiers[0] ? identifiers[0].identifier : 'N/A'
    end

    def patient_residence(patient)
      address = patient.person.addresses[0]
      return 'N/A' unless address

      district = address.state_province || 'Unknown District'
      village = address.city_village || 'Unknown Village'
      "#{district}, #{village}"
    end

    def patient_current_regimen(patient)
      concept = concept('Regimen Category')
      return 'UNKNOWN' unless concept
      regimens = Observation.where person_id: patient.patient_id,
                                   concept_id: concept.concept_id
      regimens = regimens.order date_created: :desc
      regimens[0] ? regimens[0].value_text : 'N/A'
    end

    def patient_current_outcome(patient)
      patient_program = PatientProgram.find_by patient_id: patient.patient_id,
                                               program_id: @program.program_id
      return 'UNKNOWN' unless patient_program

      program_states = ProgramWorkflowState.joins(:patient_states).where(
        'patient_state.patient_program_id = ?',
        patient_program.patient_program_id
      ).order('patient_state.date_created')

      return 'N/A' if program_states.empty?

      program_states[0].concept.concept_names[0].name
    end

    def patient_art_reason(patient)
      concept = concept('Reason for ART eligibility')
      return 'UNKNOWN' unless concept

      obs_list = Observation.where concept_id: concept.concept_id,
                                   person_id: patient.patient_id
      obs_list = obs_list.order(date_created: :desc).limit(1)
      return 'N/A' if obs_list.empty?

      obs = obs_list[0]
      Concept.find(obs.value_coded.to_i).concept_names[-1].name
    end

    def patient_art_period(patient)
      concept = concept('ART start date')
      return 'UNKNOWN', 'UNKNOWN' unless concept

      obs_list = Observation.where concept_id: concept.concept_id,
                                   person_id: patient.patient_id
      obs_list = obs_list.order(date_created: :desc).limit(1)
      obs = obs_list[0]
      return 'N/A', 'N/A' unless obs

      duration = (Time.now - obs.value_datetime) / SECONDS_IN_MONTH
      [obs.value_datetime.strftime('%d/%b/%y'), duration]
    end
  end
end
