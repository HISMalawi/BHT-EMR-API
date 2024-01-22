# frozen_string_literal: true

require 'ostruct'

class TBService::PatientVisit
    include ModelUtils

    delegate :get, to: :patient_observation

    attr_reader :patient, :date

    def initialize(patient, date)
      @patient = patient
      @date = date
      @vital_stats = TBService::PatientVitalStats.new(@patient)
      @visit_drugs = TBService::PatientDrugs.new(@patient, @date)
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
      c_name = 'Appointment date'
      datetime = get(@patient, c_name, @date).first&.value_datetime
      datetime ? datetime.strftime('%d/%b/%Y') : 'N/A'
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
      TBService::PatientObservation
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
