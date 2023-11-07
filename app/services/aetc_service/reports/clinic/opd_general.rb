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
                    @age_groups = ['> 14 to < 20', '20 to 30'].map{|g|"'#{g}'"}
                end

                # The old architecture used the same query to generate the reports
                # Hence each case calling the same method  
                # This will be changed after further details/requirements are gathered 
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

                # global variable with age groups
                age_groups = [
                    '< 6 months',
                    '>14 to <20', 
                    '6 months to <1 yr', 
                    '1 to <5', 
                    '5 to 14', 
                    '> 14 to < 20',
                    '20 to 30',
                    '>30 to <40',
                    '40 to <50'
                ]

                # Helper method to convert age group string to age range
                def age_group_to_range(age_group)
                    case age_group
                    when '< 6 months'
                    (0..6)
                    when '>14 to <20'
                    (168..239)
                    when '6 months to <1 yr'
                    (6..11)
                    when '1 to <5'
                    (12..59)
                    when '5 to 14'
                    (60..168)
                    when '20 to 30'
                    (168..240)
                    when '>30 to <40'
                    (240..360)
                    when '40 to <50'
                    (480..600)
                    else
                    (0..Float::INFINITY)  # Default range
                    end
                end

                def fetch_general_diagnosis_report
                    # Filter age groups based on the given start_age and end_age
                    filtered_age_groups = age_groups.select do |age_group|
                        age_range = age_group_to_range(age_group)
                        age_range.overlaps?(start_age..end_age)
                    end

                    age_group_conditions = filtered_age_groups.map do |age_group|
                        "WHEN #{age_group_to_sql(age_group)}"
                    end.join("\n")

                    results = ActiveRecord::Base.connection.select_all <<~SQL
                        SELECT cn.name AS diagnosis, e.patient_id AS person_id,  
                        CASE
                            #{age_group_conditions}
                            ELSE '> 50'
                        END AS age_group
                        FROM encounter e
                        INNER JOIN patient p ON p.patient_id = e.patient_id AND p.voided = 0
                        INNER JOIN person pe ON pe.person_id = e.patient_id AND pe.voided = 0
                        INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.name = 'OUTPATIENT DIAGNOSIS' AND et.retired = 0
                        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id IN ("#{concept('PRIMARY DIAGNOSIS').concept_id}", "#{concept('SECONDARY DIAGNOSIS').concept_id}")
                        INNER JOIN concept_name cn ON cn.concept_id = o.value_coded AND cn.voided = 0
                        WHERE e.encounter_datetime >= '#{start_date}' AND e.encounter_datetime <= '#{end_date}' AND e.voided = 0
                        GROUP BY diagnosis, person_id, age_group
                    SQL
                    map_object(results)
                end

                def age_group_to_sql(age_group)
                    age_range = age_group_to_range(age_group)
                    min_age_in_months = age_range.min
                    max_age_in_months = age_range.max == Float::INFINITY ? 'NULL' : age_range.max
                    "timestampdiff(month, pe.birthdate, '2021-10-03 23:59:59 +0200') BETWEEN #{min_age_in_months} AND #{max_age_in_months} THEN #{age_group}"
                end

                def map_object data
                    report = []
                    data.each do |p|
                        diagnosis = p['diagnosis']
                        person_id = p['person_id']
                        
                        diagnosis_entry = report.find { |entry| entry['diagnosis'] == diagnosis }

                        if diagnosis_entry.nil?
                        report << { 'diagnosis' => diagnosis, 'patients' => [person_id] }
                        else
                        diagnosis_entry['patients'] << person_id
                        end
                    end
                    report
                end

            end
        end
    end
end