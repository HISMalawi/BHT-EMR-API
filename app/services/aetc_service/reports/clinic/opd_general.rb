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

                # Define your global variable with age groups
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
                            ELSE 'Other'
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
                end

                def age_group_to_sql(age_group)
                    age_range = age_group_to_range(age_group)
                    min_age_in_months = age_range.min
                    max_age_in_months = age_range.max == Float::INFINITY ? 'NULL' : age_range.max
                    "timestampdiff(month, pe.birthdate, '2021-10-03 23:59:59 +0200') BETWEEN #{min_age_in_months} AND #{max_age_in_months} THEN #{age_group}"
                end

                # def age_group_to_sql(age_group)
                #     age_range = age_group_to_range(age_group)
                #     min_age_in_months = age_range.min
                #     max_age_in_months = age_range.max == Float::INFINITY ? 'NULL' : age_range.max
                #     "WHEN timestampdiff(month, pe.birthdate, '2021-10-03 23:59:59 +0200') age_in_months BETWEEN #{min_age_in_months} AND #{max_age_in_months} THEN #{age_group}"
                # end

                # Helper method to convert age group string to SQL condition
                # def age_group_to_sql(age_group)
                #     age_range = age_group_to_range(age_group)
                #     max_value = age_range.max == Float::INFINITY ? 'NULL' : age_range.max
                #     "BETWEEN timestampdiff(month, pe.birthdate, '2021-10-03 23:59:59 +0200') age_in_months AND #{max_value}"
                # end


                # def fetch_general_diagnosis_report
                #     primary_diagnosis = ConceptName.find_by_name("PRIMARY DIAGNOSIS").concept_id
                #     secondary_diagnosis = ConceptName.find_by_name("SECONDARY DIAGNOSIS").concept_id
                  
                #     results = ActiveRecord::Base.connection.select_all <<~SQL
                #       SELECT name diagnosis, p.person_id,
                #       age_group(p.birthdate, DATE(obs_datetime), DATE(p.date_created), p.birthdate_estimated) age_groups
                #       FROM `obs`
                #       INNER JOIN person p ON obs.person_id = p.person_id
                #       INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
                #       WHERE (obs.concept_id IN (#{primary_diagnosis}, #{secondary_diagnosis})
                #       AND obs_datetime >= '#{start_date}'
                #       AND obs_datetime <= '#{end_date}' AND obs.voided = 0)
                #       ORDER BY c.name ASC
                #     SQL
                  
                #     map_query(results)
                #   end
                  
                #   AGE_IN_MONTHS_MAP = {
                #     '< 6 months' => [0, 6],
                #     '6 months to < 1 yr' => [6, 12],
                #     '1 to < 5' => [12, 60],
                #     '5 to 14' => [60, 168],
                #     '> 14 to < 20' => [168, 240],
                #     '20 to 30' => [240, 360],
                #     '>30 to <40' => [360, 480],
                #     '40 to <50' => [480, 600]
                #   }.freeze
                  
                #   def map_query(data)
                #     report = {}
                  
                #     data.each do |obj|
                #       diagnosis = obj['diagnosis']
                #       person_id = obj['person_id']
                  
                #       report[diagnosis] ||= []
                #       unless report[diagnosis].include?(person_id)
                #         report[diagnosis] << person_id
                #       end
                #     end
                  
                #     report
                #   end
            end
        end
    end
end