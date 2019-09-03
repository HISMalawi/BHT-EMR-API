# frozen_string_literal: true

module TBService::Reports::Tbhiv
  class << self
    def new_and_relapse_tb_cases_notified (start_date, end_date)
      patients = patients_query.new_patients(start_date, end_date)

      bacterial = relapse_patients_query.bacteriologically_confirmed(start_date, end_date)
      clinic = relapse_patients_query.clinically_confirmed(start_date, end_date)

      return [] if patients.empty? && bacterial.empty? && clinic.empty?

      new_ids = patients.map(&:patient_id)
      bacterial_ids = bacterial.map { |patient| patient['patient_id'] }
      clinical_ids = clinic.map { |patient| patient['patient_id'] }

      ids = (new_ids + bacterial_ids + clinical_ids).uniq

      persons_query.group_by_gender(ids)
    end

    def total_with_hiv_result_documented (start_date, end_date)
      hiv_status = concept('HIV Status')
      type = encounter_type('TB_Initial')

      patients = Observation.select(:person_id).distinct\
                            .joins(:encounter)\
                            .where(:encounter => { encounter_type: type,
                                                   encounter_datetime: start_date..end_date },
                                   :obs => { concept_id: hiv_status })

      return [] if patients.empty?

      ids = patients.map(&:person_id)

      persons_query.group_by_gender(ids)
    end

    def total_tested_hiv_positive (start_date, end_date)
      hiv_status = concept('HIV Status')
      type = encounter_type('TB_Initial')
      positive = concept('Positive')

      patients = Observation.select(:person_id).distinct\
                            .joins(:encounter)\
                            .where(:encounter => { encounter_type: type,
                                                   encounter_datetime: start_date..end_date },
                                   :obs => { concept_id: hiv_status,
                                             value_coded: positive})

      return [] if patients.empty?

      ids = patients.map(&:person_id)

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
        common = tb_states.select do |s|
          if s.patient_program.nil? || state.patient_program.nil?
            next
          end
          s.date_created > state.date_created && s.patient_program.patient_id == state.patient_program.patient_id
        end
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
        common = art_states.select do |s|
          if s.patient_program.nil? || state.patient_program.nil?
            next
          end
          s.date_created > state.date_created && s.patient_program.patient_id == state.patient_program.patient_id
        end
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

    def relapse_patients_query
      TBQueries::RelapsePatientsQuery.new
    end
  end
end