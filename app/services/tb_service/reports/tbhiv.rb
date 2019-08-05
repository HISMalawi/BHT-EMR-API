# frozen_string_literal: true

module TBService::Reports::Tbhiv
  class << self
    def new_and_relapse_tb_cases_notified (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial'], start_date, end_date)

      relapse_patients = states_query.any_relapse(start_date, end_date)

      return [] if patients.empty? && relapse_patients.empty?

      new_ids = patients.map(&:patient_id)

      ids = (new_ids + relapse_patients).uniq

      persons_query.group_by_gender(ids)
    end

    def total_with_hiv_result_documented (start_date, end_date)
      patients = patients_query.with_obs_ignore_value('TB_Initial', 'HIV Status', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      persons_query.group_by_gender(ids)
    end

    def total_tested_hiv_positive (start_date, end_date)
      patients = patients_query.with_obs('TB_Initial', 'HIV Status', 'Positive', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      persons_query.group_by_gender(ids)
    end

    def started_cpt (start_date, end_date)
      persons = person_drugs_query.started_cpt(start_date, end_date)

      return [] if persons.empty?

      ids = persons.map { |foo| foo['person_id']}

      persons_query.group_by_gender(ids)
    end

    def started_art_before_tb_treatment (start_date, end_date)
      tb_states = states_query.in_tb_treatment(start_date, end_date)

      return [] if tb_states.empty?

      art_states = states_query.in_art_treatment(start_date, end_date)

      return [] if art_states.empty?

      patients_on_art_before_tb = art_states.select do |state|
        common = tb_states.select { |s| s.date_created > state.date_created && s.patient_program.patient_id == state.patient_program.patient_id }
        common.size > 0
      end

      return [] unless patients_on_art_before_tb

      ids = patients_on_art_before_tb.map { |state| state.patient_program.patient_id }

      persons_query.group_by_gender(ids)
    end

    def started_art_while_on_treatment (start_date, end_date)
      tb_states = states_query.in_tb_treatment(start_date, end_date)

      return [] if tb_states.empty?

      art_states = states_query.in_art_treatment(start_date, end_date)

      return [] if art_states.empty?

      patients_on_tb_before_art = tb_states.select do |state|
        common = art_states.select { |s| s.date_created > state.date_created && s.patient_program.patient_id == state.patient_program.patient_id }
        common.size > 0
      end

      return [] unless patients_on_tb_before_art

      ids = patients_on_tb_before_art.map { |state| state.patient_program.patient_id }

      persons_query.group_by_gender(ids)
    end

    private
    def person_drugs_query
      TBQueries::PersonDrugsQuery.new.search
    end

    def patients_query
      TBQueries::PatientsQuery.new.search
    end

    def states_query
      TBQueries::PatientStatesQuery.new
    end

    def persons_query
      TBQueries::PersonsQuery.new
    end
  end
end