# frozen_string_literal: true

module RadiologyService
  module Reports
    module Clinic
      # This class is used to generate the daily radiology report.
      class DailyReport
        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          exam_line = []
          report.each do |ob|
            exam_line << {
              exam_name: Concept.find_by_concept_id(ob['order_concept_id']).shortname,
              exam_value_name: Concept.find_by_concept_id(ob['exam_value_coded']).shortname,
              exam_total: ob['exam_total']
            }
          end
          exam_line
        end

        private

        def report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT od.concept_id as order_concept_id,o.value_coded as exam_value_coded,COUNT(o.value_coded) as exam_total
            FROM obs o
            INNER JOIN orders od ON od.encounter_id = o.encounter_id
            INNER JOIN encounter en ON en.encounter_id = o.encounter_id
            AND od.order_type_id = #{radiology_order_type_id}
            AND o.concept_id = #{examination_concept_id}
            AND en.encounter_type = #{radiology_encounter_id}
            AND od.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('ULTRASOUND','MAMMOGRAPHY','MRI SCAN','CT SCAN','XRAY', 'BONE DENSITOMETRY'))
            AND od.voided = 0
            AND o.voided = 0
            AND DATE(o.obs_datetime) BETWEEN '#{@start_date}' AND '#{@end_date}'
            GROUP BY od.concept_id,o.value_coded
            ORDER BY od.concept_id DESC
          SQL
        end

        def examination_concept_id
          @examination_concept_id ||= ConceptName.find_by_name('EXAMINATION').concept_id
        end

        def radiology_encounter_id
          @radiology_encounter_id ||= EncounterType.find_by_name('RADIOLOGY EXAMINATION').encounter_type_id
        end

        def radiology_order_type_id
          @radiology_order_type_id ||= OrderType.find_by_name('Radiology').order_type_id
        end
      end
    end
  end
end
