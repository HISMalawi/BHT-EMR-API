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
      type = encounter_type('TB_Initial')
      program = program('TB Program')
      hiv_status = concept('HIV Status')

      patients = Encounter.select(:patient_id).distinct\
                          .joins(:observations)\
                          .where(:encounter => { encounter_type: type,
                                                 program_id: program,
                                                 encounter_datetime: start_date..end_date },
                                 :obs => { concept_id: hiv_status })

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      persons_query.group_by_gender(ids)
    end

    def total_tested_hiv_positive (start_date, end_date)
      type = encounter_type('TB_Initial')
      program = program('TB Program')
      hiv_status = concept('HIV Status')
      positive = concept('Positive')

      patients = Encounter.select(:patient_id).distinct\
                          .joins(:observations)\
                          .where(:encounter => { encounter_type: type,
                                                 program_id: program,
                                                 encounter_datetime: start_date..end_date },
                                 :obs => { concept_id: hiv_status, value_coded: positive })

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
      ids = tb_treatment_query.started_after_art(start_date, end_date)

      persons_query.group_by_gender(ids)
    end

    def started_art_while_on_treatment (start_date, end_date)
      ids = tb_treatment_query.started_before_art(start_date, end_date)

      persons_query.group_by_gender(ids)
    end

    private
    def person_drugs_query
      TbQueries::PersonDrugsQuery.new.search
    end

    def patients_query
      TbQueries::PatientsQuery.new.search
    end

    def persons_query
      TbQueries::PersonsQuery.new
    end

    def relapse_patients_query
      TbQueries::RelapsePatientsQuery.new
    end

    def tb_treatment_query
      TbQueries::TbTreatmentQuery.new
    end
  end
end