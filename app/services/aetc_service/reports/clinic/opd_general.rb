# frozen_string_literal: true
module AETCService
    module Reports
        module Clinic
            class OpdGeneral
                include ModelUtils
                attr_reader :start_date, :end_date, :start_age, :end_age, :report_type, :age_groups
                
                def initialize(start_date:, end_date:, **kwargs)
                    @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
                    @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
                    @start_age = JSON.parse(kwargs[:start_age])
                    @end_age = JSON.parse(kwargs[:end_age])
                    @report_type = JSON.parse(kwargs[:report_type])
                    @age_groups = ['> #{@start_age} to < #{@end_age}']
                end

                def fetch_report
                    case @report_type
                    when 'General outpatient'
                        fetch_general_outpatient_report
                    when 'Pediatrics'
                        fetch_peds_report
                    when 'General Diagnosis'
                        fetch_general_diagnosis_report
                    when 'Pediatrics Diagnosis'
                        fetch_peds_diagnosis_report
                    else
                        fetch_adults_diagnosis_report
                    end
                end

                def fetch_general_outpatient_report 
                end

                def fetch_peds_report
                end

                def fetch_general_diagnosis_report
                    results = ActiveRecord::Base.connection.select_all <<~SQL
                    SELECT name diagnosis , city_village village , 
                    age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
                    FROM `obs` 
                    INNER JOIN person p ON obs.person_id = obs.person_id
                    INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
                    INNER JOIN person_address pd ON obs.person_id = pd.person_id
                    WHERE (obs.concept_id=#{concept} 
                    AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
                    AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
                    GROUP BY diagnosis , village ,age_groups
                    HAVING age_groups IN (#{age_groups.join(',')}) AND diagnosis = ?
                    ORDER BY c.name ASC
                    SQL

                    map_query results
                end

                def fetch_peds_diagnosis_report
                end

                def fetch_adults_diagnosis_report
                end

                def map_query data
                    report = data.collect |obj, index|
                      d = {
                        'no' => index+1,
                        'data_element' => obj[:value],
                        
                      }
                      d
                    end
                    report
                end
            end
        end
    end
end