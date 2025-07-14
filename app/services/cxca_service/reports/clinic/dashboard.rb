module CxcaService
  module Reports
    module Clinic
      class Dashboard

        attr_accessor :start_date, :end_date, :report
        
        def initialize(start_date: Date.today, end_date: Date.today)
          @start_date = ActiveRecord::Base.connection.quote(start_date.to_date.strftime('%Y-%m-%d 00:00:00'))
          @end_date = ActiveRecord::Base.connection.quote(end_date.to_date.strftime('%Y-%m-%d 23:59:59'))
          @report = build_report
        end

        def build_report
          methods = ['VIA', 'Speculum Exam', 'PAP Smear', 'HPV DNA']
          age_groups = ['15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50+']
          [:reffered, :walkin].each_with_object({}) do |section, report|
            report[section] = age_groups.each_with_object({}) do |age_group, age_group_report|
              age_group_report[age_group] = methods.each_with_object({}) do |method, method_report|
                method_report[method] = []
              end
            end
          end
        end

        def find_report
          dashboard
        end

        def dashboard
          reffered = refered_from_art&.map { |r| r['person_id'] }
          (screened_today || []).each do |person|
            section = reffered.include?(person['person_id']) ? :reffered : :walkin
            method = person['screening_method']
            age_group = person['age_group']
            report[section][age_group][method] << person['person_id']
          end

          report
        end

        def refered_from_art
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT obs.person_id
            FROM obs
            INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.voided = 0
            WHERE obs.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Offer CxCa' AND concept_name.voided = 0)
              AND obs.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Yes' AND concept_name.voided = 0)
              AND obs.obs_datetime BETWEEN #{start_date} AND #{end_date}
              AND encounter.voided = 0
              AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'HIV PROGRAM')
          SQL
        end

        def screened_today
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT obs.person_id, screening.screening_method, cxca_age_group(p.birthdate, #{end_date}) age_group
            FROM obs
            INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id
            INNER JOIN person p ON p.person_id = obs.person_id
              AND p.voided = 0
            LEFT JOIN (
              SELECT person_id, concept_name.name AS screening_method
              FROM obs
              INNER JOIN concept_name ON concept_name.concept_id = obs.value_coded
                AND concept_name.voided = 0
              INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id
                AND encounter.voided = 0
                AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'CxCa program' LIMIT 1) 
              WHERE obs.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'CxCa screening method' AND concept_name.voided = 0 LIMIT 1)
                AND obs_datetime BETWEEN #{start_date} AND #{end_date}
                AND obs.voided = 0
              GROUP BY person_id
            ) AS screening ON screening.person_id = obs.person_id
            WHERE obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Reason for visit' AND concept_name.voided = 0)
              AND obs.obs_datetime BETWEEN #{start_date} AND #{end_date}
              AND encounter.voided = 0
              AND encounter.program_id = (SELECT program_id FROM program WHERE name = 'CxCa program' LIMIT 1)
            GROUP BY obs.person_id
          SQL
        end
      end
    end
  end
end