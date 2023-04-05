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
          report
        end

        private

        def report
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT ord.concept_id, o.value_coded, cn.name exam_name, vcn.name exam_value_name, count(DISTINCT(ord.order_id)) exam_total
            FROM orders ord
            INNER JOIN concept_name cn ON cn.concept_id = ord.concept_id AND cn.voided = 0
            INNER JOIN obs o ON o.order_id = ord.order_id AND o.voided = 0 AND o.concept_id = 1336 -- examination concept
            INNER JOIN concept_name vcn ON vcn.concept_id = o.value_coded AND vcn.voided = 0 AND vcn.name IS NOT NULL AND vcn.name != ''
            WHERE ord.concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('ULTRASOUND','MAMMOGRAPHY','MRI SCAN','CT SCAN','XRAY', 'BONE DENSITOMETRY') AND voided = 0)
            AND ord.start_date BETWEEN '#{@start_date}' AND '#{@end_date}'
            GROUP BY ord.concept_id, o.value_coded
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
