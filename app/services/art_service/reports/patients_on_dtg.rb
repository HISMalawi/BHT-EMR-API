# frozen_string_literal: true

module ArtService
  module Reports
    class PatientsOnDTG
      attr_reader :start_date, :end_date

      HIV_PROGRAM_ID = 1
      ARV_NUMBER_TYPE_ID = 4

      def initialize(start_date:, end_date:, **_)
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        DrugOrder.joins(:order)
                 .joins('INNER JOIN encounter USING (encounter_id)')
                 .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = orders.patient_id')
                 .where(drug: dtg_drugs,
                        encounter: { program_id: HIV_PROGRAM_ID },
                        patient_identifier: { identifier_type: ARV_NUMBER_TYPE_ID })
                 .where('start_date BETWEEN ? AND ?', start_date, end_date)
                 .group('orders.patient_id')
                 .select('identifier')
                 .map(&:identifier)
      end

      private

      def dtg_drugs
        Drug.where(concept_id: ConceptName.find_by_name('Dolutegravir').concept_id)
      end
    end
  end
end
