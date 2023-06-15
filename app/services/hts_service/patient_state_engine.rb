module HTSService
  class PatientStateEngine

    include ModelUtils

    attr_accessor :patient, :date

    HTS_PROGRAM = Program.find_by_name('HTC Program')
    CURRENT_FACILITY = Location.find(GlobalProperty.find_by_property('current_health_center_id').property_value.to_i).name

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def art_full_summary
       ARTService::PatientSummary.new(patient, date).full_summary
    end

    # Link patient to HTS program
    # NB: only link patient if they have been registed as a new patient in ART module
    def link_patient
      return nil unless %i[patient_is_in_program? patient_is_not_linked? is_new_patient?].all? { |method| send(method) }
      ActiveRecord::Base.transaction do
        encounter = create_art_outcome_encounter
        observations = build_art_outcome_obs.collect do |ob|
          ObservationService.new.create_observation(encounter, ob)
        end
      end
    end

    private

    def build_art_outcome_obs
      [
        {concept_id: concept('Antiretroviral status or outcome').concept_id, value_coded: concept('Linked').concept_id},
        {concept_id: concept('Outcome date').concept_id, value_datetime: date},
        {concept_id: concept('ART clinic location').concept_id, value_text: CURRENT_FACILITY},
        {concept_id: concept('Art number').concept_id,  value_text: art_full_summary[:arv_number]}
      ]
    end

    def is_new_patient?
      Observation.where(person_id: patient.patient_id,
                        concept: concept('Type of patient')
                        ).first.value_coded === 7572 ? true : false
    end

    def create_art_outcome_encounter
      EncounterService.new.create(
        type: EncounterType.find_by_name('ART_FOLLOWUP'),
        patient: patient,
        program: HTS_PROGRAM,
        encounter_datetime: date,
      )
    end

    def patient_is_not_linked?
      exists = Observation.where(person_id: patient.patient_id,
                        concept: concept('Antiretroviral status or outcome'),
                        value_coded: concept('Linked').concept_id).exists?
      Logger.debug "Patient #{patient.id} already linked to HTS" unless !exists
      !exists
    end

    def patient_is_in_program?
      Patient.find(patient.patient_id).patient_programs.where(program: HTS_PROGRAM).exists?
    end

  end

end