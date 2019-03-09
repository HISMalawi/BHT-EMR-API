# frozen_string_literal: true

module ARTService
  class ReportEngine
    attr_reader :program

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => ARTService::Reports::Cohort,
      'COHORT_DISAGGREGATED' => ARTService::Reports::CohortDisaggregated,
      'VISITS' => ARTService::Reports::VisitsReport
    }.freeze

    def generate_report(type:, **kwargs)
      call_report_manager(:build_report, type: type, **kwargs)
    end

    def find_report(type:, **kwargs)
      call_report_manager(:find_report, type: type, **kwargs)
    end

    def cohort_report_raw_data(l1, l2)
      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT e.*, t2.cum_outcome,  
      t3.identifier arv_number, t.birthdate,
      t.gender, t4.given_name, t4.family_name
      FROM temp_earliest_start_date e 
      INNER JOIN person t ON t.person_id = e.patient_id
      INNER JOIN temp_patient_outcomes t2 
      ON t2.patient_id = e.patient_id
      RIGHT JOIN patient_identifier t3 ON t3.patient_id = e.patient_id
      AND t3.voided = 0 AND t3.identifier_type = 4 
      RIGHT JOIN person_name t4 ON t4.person_id = e.patient_id
      AND t4.voided = 0 GROUP BY t2.patient_id LIMIT #{l1}, #{l2};
EOF

      list = [];
      (data || []).each do |record|
        list << {
          patient_id: record['patient_id'],
          given_name: record['given_name'],
          family_name: record['family_name'],
          birthdate: record['birthdate'],
          gender: record['gender'],
          date_enrolled: record['date_enrolled'],
          earliest_start_date: record['earliest_start_date'],
          arv_number: record['arv_number'],
          outcome:  record['cum_outcome']
        }
      end

      return list
    end

    private

    def call_report_manager(method, type:, **kwargs)
      start_date = kwargs.delete(:start_date)
      end_date = kwargs.delete(:end_date)
      name = kwargs.delete(:name)

      report_manager = REPORTS[type.name.upcase].new(
        type: type, name: name, start_date: start_date, end_date: end_date
      )
      method = report_manager.method(method)
      if kwargs.empty?
        method.call
      else
        method.call(**kwargs)
      end
    end
  end
end
