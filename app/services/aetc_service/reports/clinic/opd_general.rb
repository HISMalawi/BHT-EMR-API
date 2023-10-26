# frozen_string_literal: true
module AetcService
    module Reports
        module Clinic
            class OpdGeneral
                attr_reader :start_date, :end_date, :start_age, :end_age, :report_type, :age_groups
                
                def initialize(start_date:, end_date:, **kwargs)
                    @start_date = start_date.to_date.beginning_of_day
                    @end_date = end_date.to_date.end_of_day
                    @start_age = JSON.parse(kwargs[:start_age])
                    @end_age = JSON.parse(kwargs[:end_age])
                    @report_type = kwargs[:report_type]
                    # @age_groups = ["> #{@start_age} to < #{@end_age}"].map{|g|"'#{g}'"}
                    @age_groups = ['> 14 to < 20'].map{|g|"'#{g}'"}
                end

                def fetch_report
                    case @report_type
                    when 'General outpatient'
                        fetch_general_outpatient_report
                    when 'Pediatrics'
                        fetch_peds_report
                    when 'General Diagnosis'
                        fetch_general_diagnosis_report
                    else 
                        fetch_peds_diagnosis_report
                    end
                end

                def fetch_general_outpatient_report 
                    fetch_general_diagnosis_report
                end

                def fetch_peds_report 
                    fetch_general_diagnosis_report
                end
                
                def fetch_peds_diagnosis_report 
                    fetch_general_diagnosis_report
                end

                def fetch_general_diagnosis_report
                    concept = ConceptName.find_by_name("PRIMARY DIAGNOSIS").concept_id

                    results = ActiveRecord::Base.connection.select_all <<~SQL
                    SELECT name diagnosis , 
                    age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
                    FROM `obs` 
                    INNER JOIN person p ON obs.person_id = obs.person_id
                    INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
                    WHERE (obs.concept_id=#{concept} 
                    AND obs_datetime >= '#{start_date}'
                    AND obs_datetime <= '#{end_date}' AND obs.voided = 0) 
                    GROUP BY diagnosis,age_groups
                    HAVING age_groups IN (#{age_groups.join(',')})
                    ORDER BY c.name ASC
                    SQL

                    map_query results
                end

                AGE_IN_MONTHS_MAP = {
                    '< 6 months' => [0, 6],
                    '6 months to < 1 yr' => [6, 12],
                    '1 to < 5' => [12, 60],
                    '5 to 14' => [60, 168],
                    '> 14 to < 20' => [168, 240],
                    '20 to 30' => [240, 360],
                    '>30 to <40' => [360, 480],
                    '40 to <50' => [480, 600]
                  }.freeze

                def map_query data
                    report = {}

                    data.each_with_index do |obj, index|
                      report[obj[:diagnosis]] ||= 0
                      report[obj[:diagnosis]] += 1
                    end
                    report
                end
            end
        end
    end
end