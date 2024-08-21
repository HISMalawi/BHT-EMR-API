# frozen_string_literal: true

module TbService
  # A summary of a patient's ART clinic visit
  class PatientVisit
    include ModelUtils

    delegate :get, to: :patient_observation

    attr_reader :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
      @vital_stats = TbService::PatientVitalStats.new(@patient)
      @visit_drugs = TbService::PatientDrugs.new(@patient, @date)
    end

    def patient_outcome
      begin
        state = patient_state_service.find_patient_state(get_program, @patient, @date)
        state.nil? ? blank_outcome : state
      rescue
        blank_outcome
      end
    end

    def next_appointment
      Observation.where(person: patient.person, concept: concept('Appointment date'))\
                 .order(obs_datetime: :desc)\
                 .first\
                 &.value_datetime
    end

    def tb_status
      state = begin
        Concept.find(Observation.where(['person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= ? AND value_coded IS NOT NULL',
                                        patient.id, ConceptName.find_by_name('TB STATUS').concept_id,
                                        visit_date.to_date]).order('obs_datetime DESC, date_created DESC').first.value_coded).fullname
      rescue StandardError
        'Unk'
      end

      program_id = Program.find_by_name('TB PROGRAM').id
      patient_state = PatientState.where(["patient_state.voided = 0 AND p.voided = 0
         AND p.program_id = ? AND DATE(start_date) <= DATE('#{date}') AND p.patient_id =?",
                                          program_id, patient.id]).joins('INNER JOIN patient_program p  ON p.patient_program_id = patient_state.patient_program_id').order('start_date DESC').first

      return state if patient_state.blank?

      ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name
    end

    def height
      @vital_stats.height
    end

    def weight
      @vital_stats.weight
    end

    def bmi
      @vital_stats.bmi
    end

    def adherence
      @visit_drugs.adherence
    end

    def pills_brought
      @visit_drugs.pills_brought
    end

    def pills_dispensed
      @visit_drugs.pills_dispensed
    end

    private

    def patient_state_service
      PatientStateService.new
    end

    def patient_observation
      TbService::PatientObservation
    end

    def get_program
      ipt? ? program('IPT Program') : program('TB Program')
    end

    def ipt?
      PatientProgram.joins(:patient_states)\
                    .where(patient_program: { patient_id: @patient,
                                              program_id: program('IPT Program') },
                           patient_state: { end_date: nil })\
                    .exists?
    end

    def blank_outcome
      OpenStruct.new(name: 'Unknown', date_created: nil, start_date: nil)
    end
  end
