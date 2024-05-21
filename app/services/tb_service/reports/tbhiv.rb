# frozen_string_literal: true

module TbService::Reports::Tbhiv
  class << self
    def new_and_relapse_tb_cases_notified(start_date, end_date)
      patients = patients_query.new_patients(start_date, end_date)

    def report_format(indicator)
      {
        indicator: indicator,
        male: [],
        female: [],
        total: []
      }
    end

    def total_with_hiv_result_documented(start_date, end_date)
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

    def total_tested_hiv_positive(start_date, end_date)
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

    def started_cpt(start_date, end_date)
      persons = person_drugs_query.started_cpt(start_date, end_date)

      return [] if persons.empty?

      ids = persons.map { |foo| foo['person_id'] }

      persons_query.group_by_gender(ids)
    end

    def started_art_before_tb_treatment(start_date, end_date)
      ids = tb_treatment_query.started_after_art(start_date, end_date)

      ids = (new_cases + relapses)
      Patient.where(patient_id: ids)
    end

    def started_art_while_on_treatment(start_date, end_date)
      ids = tb_treatment_query.started_before_art(start_date, end_date)

      unless cases.empty? && relapses.empty?
        all = Patient.where(patient_id: (cases + relapses))
        query = hiv_result_query.new(all).ref
        query.documented
      end
    end

    def total_tested_hiv_positive(start_date, end_date)
      new_cases = new_patients_query.ref(start_date, end_date)
      relapses = relapse_patients_query.ref(start_date, end_date)

      unless new_cases.empty? && relapses.empty?
        all = Patient.where(patient_id: (new_cases + relapses))
        query = hiv_result_query.new(all).ref
        query.positive
      end
    end

    def started_cpt(start_date, end_date)
      query = new_patients_query.ref(start_date, end_date)
      relapses = relapse_patients_query.ref(start_date, end_date)
      Patient.where(patient_id: (relapses.on_cpt + query.on_cpt))
    end

    def started_art_before_tb_treatment(start_date, end_date)
      new_cases = new_patients_query.ref(start_date, end_date)
      relapses = relapse_patients_query.ref(start_date, end_date)

      ids = (new_cases.started_before_art + relapses.started_before_art)
      Patient.where(patient_id: ids)
    end

    def started_art_while_on_treatment(start_date, end_date)
      new_cases = new_patients_query.ref(start_date, end_date)
      relapses = relapse_patients_query.ref(start_date, end_date)

      ids = (new_cases.started_while_art + relapses.started_while_art)
      Patient.where(patient_id: ids)
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
end
