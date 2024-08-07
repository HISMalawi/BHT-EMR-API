# frozen_string_literal: true

module ArtService
  module Reports
    ##
    # MER drug dispensation report
    #
    # Captures total number of packs of each drug dispensed in a given time period.
    class DrugDispensations
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = ActiveRecord::Base.connection.quote(start_date)
        @end_date = ActiveRecord::Base.connection.quote(end_date)
      end

      def find_report
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT drug.name AS drug_name,
                 dispensation.value_numeric AS pack_size,
                 COUNT(*) AS packs_dispensed
          FROM obs AS dispensation
          INNER JOIN encounter
            ON encounter.encounter_id = dispensation.encounter_id
            AND encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
            AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Dispensing')
            AND encounter.voided = 0
          INNER JOIN orders
            ON orders.order_id = dispensation.order_id
            AND orders.start_date BETWEEN #{start_date} AND #{end_date}
            AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
            AND orders.voided = 0
          INNER JOIN drug_order
            ON drug_order.order_id = orders.order_id
            AND drug_order.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
            AND drug_order.quantity > 0
          INNER JOIN drug
            ON drug.drug_id = drug_order.drug_inventory_id
            AND drug.retired = 0
          WHERE dispensation.voided = 0
            AND dispensation.value_numeric > 0
            AND dispensation.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Amount dispensed' AND voided = 0)
          GROUP BY dispensation.value_numeric
        SQL
      end
    end
  end
end
