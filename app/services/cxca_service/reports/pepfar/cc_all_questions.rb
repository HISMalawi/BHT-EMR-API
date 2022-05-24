# frozen_string_literal: true

module CXCAService
  module Reports
    module Pepfar
      # class providing all major Cervical Cancer quetions
      class CcAllQuestions
        attr_reader :response

        AGE_GROUPS = ['15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50+', 'Unknown Age'].freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
          @response = init_response_structure
        end

        def general_report
          visit_report(is_returning: false)
          screening_result_report(is_returning: false)
          treatment_resport(is_returning: false)
          response
        end

        def visit_report(is_returning: true)
          type_of_screening.each do |record|
            group = response.find { |patient| patient[:age_group] == record['age_group'] }
            assign_to_type_of_screening(group, record)
          end
          return response if is_returning
        end

        def screening_result_report(is_returning: true)
          screening_result.each do |record|
            group = response.find { |patient| patient[:age_group] == record['age_group'] }
            assign_to_screening_result(group, record)
          end
          return response if is_returning
        end

        def treatment_resport(is_returning: true)
          type_of_treatment.each do |record|
            group = response.find { |patient| patient[:age_group] == record['age_group'] }
            assign_to_type_of_treatment(group, record)
          end
          return response if is_returning
        end

        private

        def init_response_structure
          struct = []
          AGE_GROUPS.each do |group|
            struct << { age_group: group, first_screen: [], rescreen: [], follow_up_screen: [],
                        result_negative: [], result_positive: [],
                        result_suspected_cancer: [], leep: [],
                        thermocoagulation: [], cryotherapy: [] }
          end
          struct
        end

        def assign_to_type_of_screening(group, record)
          visit_type = Concept.find(record['value_coded']).fullname
          return  group[:first_screen] << record['patient_id'] if visit_type == 'Initial Screening'
          return  group[:follow_up_screen] << record['patient_id'] if ['Postponed treatment', 'Referral',
                                                                       'Problem visit after treatment'].include?(visit_type)
          return  group[:rescreen] << record['patient_id'] if ['One year subsequent check-up after treatment',
                                                               'Subsequent screening'].include?(visit_type)
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/CyclomaticComplexity
        def assign_to_screening_result(group, record)
          result_type = Concept.find(record['value_coded']).fullname
          if result_type.match(/negative/i) || result_type.match(/normal/i) || result_type == 'No visible Lesion'
            return group[:result_negative] << record['patient_id']
          end
          if result_type.match(/positive/i) || result_type.match(/abnormal/i) || result_type == 'Visible Lesion'
            return group[:result_positive] << record['patient_id']
          end
          return group[:result_suspected_cancer] << record['patient_id'] if result_type.match(/suspect/i)
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity

        def assign_to_type_of_treatment(group, record)
          treatment_type = Concept.find(record['value_coded']).fullname
          return  group[:cryotherapy] << record['patient_id'] if treatment_type == 'Cryotherapy'
          return  group[:thermocoagulation] << record['patient_id'] if treatment_type == 'Thermocoagulation'
          return  group[:leep] << record['patient_id'] if treatment_type == 'LEEP'
        end

        def type_of_screening
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, cxca_age_group(p.birthdate, '#{@end_date}') as age_group, e.encounter_datetime FROM encounter e
            INNER JOIN(
              #{patient_filter('CxCa test')}
            ) e2 ON e2.patient_id = e.patient_id AND e2.encounter_datetime = e.encounter_datetime
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Reason for visit').concept_id}
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa test').id}
          SQL
        end

        def screening_result
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, cxca_age_group(p.birthdate, '#{@end_date}') age_group FROM encounter e
            INNER JOIN(
              #{patient_filter('CxCa screening result')}
            ) e2 ON e2.patient_id = e.patient_id AND e2.encounter_datetime = e.encounter_datetime
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Screening results').concept_id} AND o.value_coded IS NOT NULL
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa screening result').id}
          SQL
        end

        def type_of_treatment
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, cxca_age_group(p.birthdate, '#{@end_date}') age_group FROM encounter e
            INNER JOIN(
              #{patient_filter('CxCa treatment')}
            ) e2 ON e2.patient_id = e.patient_id AND e2.encounter_datetime = e.encounter_datetime
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Treatment').concept_id}
            AND o.value_coded IN (#{ConceptName.where(name: %w[Cryotherapy Thermocoagulation LEEP]).select(:concept_id).to_sql})
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa treatment').id}
          SQL
        end

        def patient_filter(encounter_type)
          <<~TEXT
            SELECT patient_id, max(encounter_datetime) encounter_datetime FROM encounter
            WHERE voided = 0 AND encounter_type = #{EncounterType.find_by_name(encounter_type).id}
            AND encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND patient_id IN (#{patients_in_art_program})
            GROUP BY patient_id
          TEXT
        end

        def patients_in_art_program
          return @patients_in_art_program if @patients_in_art_program

          result = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT pp.patient_id FROM patient_program pp
            INNER JOIN person p ON pp.patient_id = p.person_id and p.voided = 0
            WHERE p.gender = 'F' AND pp.program_id = #{Program.find_by_name('HIV Program').id} AND pp.voided = 0
          SQL
          @patients_in_art_program = result.map { |patient| patient['patient_id'] }.push(0).join(',')
        end
      end
    end
  end
end
