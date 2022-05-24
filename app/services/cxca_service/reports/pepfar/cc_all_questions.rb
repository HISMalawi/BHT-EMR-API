# frozen_string_literal: true

module CXCAService
  module Reports
    module Pepfar
      # class providing all major Cervical Cancer quetions
      class CcAllQuestions
        AGE_GROUPS = ['15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50+', 'Unknown Age'].freeze

        def initialize(start_date:, end_date:)
          @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data; end

        def init_response_structure
          struct = []
          AGE_GROUPS.each do |group|
            struct << { group => { first_Screen: [], rescreen: [], follow_Up_Screen: [],
                                   result_negative: [], result_positive: [], result_suspected_cancer: [] } }
          end
          struct
        end

        def type_of_screening
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, p.birthdate FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Reason for visit').concept_id}
            AND o.value_coded IN (#{ConceptName.where(name: ['Initial Screening']).to_sql})
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa test').id}
            AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND e.patient_id IN (#{patients_in_art_program})
          SQL
        end

        def screening_result
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, p.birthdate FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Screening results').concept_id}
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa screening result').id}
            AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND e.patient_id IN (#{patients_in_art_program})
          SQL
        end

        def type_of_treatment
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT e.patient_id, o.value_coded, p.birthdate FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = #{ConceptName.find_by_name('Treatment').concept_id}
            AND o.value_coded IN (#{ConceptName.where(name: %w[Cryotherapy Thermocoagulation LEEP]).select(:concept_id).to_sql})
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.voided = 0 AND e.encounter_type = #{EncounterType.find_by_name('CxCa treatment').id}
            AND e.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
            AND e.patient_id IN (#{patients_in_art_program})
          SQL
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
