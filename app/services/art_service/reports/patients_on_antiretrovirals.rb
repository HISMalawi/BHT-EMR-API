# frozen_string_literal: true

module ARTService
  module Reports
    # Retrieve all patients who are taking ARVs in a given time period.
    class PatientsOnAntiretrovirals
      attr_reader :start_date, :end_date

      def initialize(start_date:, end_date:, **_kwargs)
        @start_date = start_date
        @end_date = end_date
      end

      def self.within(start_date, end_date)
        PatientsOnAntiretrovirals.new(start_date: start_date, end_date: end_date)
                                 .patients
      end

      def find_report
        patients
      end

      def patients
        DrugOrder.select('orders.patient_id AS patient_id')
                 .joins(:order)
                 .merge(art_orders)
                 .where(drug_inventory_id: ARTService::RegimenEngine.arv_drugs,
                        quantity: 1..Float::INFINITY)
                 .where('start_date BETWEEN :start_date AND :end_date
                         OR auto_expire_date BETWEEN :start_date AND :end_date
                         OR (start_date <= :start_date AND auto_expire_date >= :end_date)',
                        start_date: start_date, end_date: end_date)
                 .group('orders.patient_id')
      end

      private

      def art_orders
        Order.joins(:encounter)
             .where('encounter.program_id = ?', ARTService::Constants::PROGRAM_ID)
      end
    end
  end
end