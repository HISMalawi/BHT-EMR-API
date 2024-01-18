# frozen_string_literal: true

module TbQueries
  class PatientStatesQuery
    STATES = {
      'TREATMENT_COMPLETE' => 93,
      'TREATMENT_FAILED' => 99,
      'DIED' => 94,
      'CURED' => 97,
      'DEFAULTED' => 96,
      'RELAPSE' => 168,
      'UNKNOWN' => 999,
      'CURRENTLY_IN_TREATMENT' => 92,
      'ART_TREATMENT' => 7
    }.freeze

    NORMAL_TREATMENT_LENGTH_IN_DAYS = 168

    def initialize(relation = PatientState.includes(:patient_program))
      @relation = relation
    end

    def relapse(ids, start_date, end_date)
      states = @relation.where('patient_program.patient_id': ids,
                               state: STATES['RELAPSE'],
                               'patient_state.date_created': start_date..end_date)

      return [] if states.empty?

      states.map { |state| state.patient_program.patient_id }
    end

    def any_relapse(start_date, end_date)
      states = @relation.where(state: STATES['RELAPSE'],
                               'patient_state.date_created': start_date..end_date)

      return [] if states.empty?

      states.map { |state| state.patient_program.patient_id }
    end

    def defaulted(ids)
      states = @relation.where(state: STATES['DEFAULTED'],
                               patient_program: { patient_id: ids },
                               end_date: nil)

      return [] if states.empty?

      states.map { |bar| bar.patient_program.patient_id }
    end

    def treatment_failed(ids, start_date, end_date)
      states = @relation.where(state: STATES['TREATMENT_FAILED'],
                               patient_program: { patient_id: ids },
                               'patient_state.date_created': start_date..end_date)

      return [] if states.empty?

      states.map { |bar| bar.patient_program.patient_id }
    end

    def any(state, patients, start_date, end_date)
      states = @relation.where('patient_program.patient_id': patients,
                               state:,
                               'patient_state.date_created': start_date..end_date)

      return [] if states.empty?

      states.map { |foo| foo.patient_program.patient_id }
    end

    def in_art_treatment(start_date, end_date)
      @relation.where(state: STATES['ART_TREATMENT'],
                      'patient_state.date_created': start_date..end_date)
    end

    def in_tb_treatment(start_date, end_date)
      @relation.where(state: STATES['CURRENTLY_IN_TREATMENT'],
                      'patient_state.date_created': start_date..end_date)
    end

    def other_previous_treatment
      states = @relation.where(state: STATES['CURRENTLY_IN_TREATMENT'],
                               end_date: nil)\
                        .where('DATEDIFF(NOW(), patient_state.date_created) > ?', NORMAL_TREATMENT_LENGTH_IN_DAYS)\
                        .or(@relation.where(state: STATES['UNKNOWN'],
                                            end_date: nil))

      return [] if states.empty?

      states.map do |foo|
        next if foo.patient_program.nil?

        foo.patient_program.patient_id
      end
    end

    def still_open(state, patients)
      states = @relation.where(state:,
                               patient_program: { patient_id: patients },
                               end_date: nil)

      return [] if states.empty?

      states.map { |bar| bar.patient_program.patient_id }
    end
  end
end
