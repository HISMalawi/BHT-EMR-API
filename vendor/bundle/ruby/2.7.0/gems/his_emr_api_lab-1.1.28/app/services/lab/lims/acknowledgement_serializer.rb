# frozen_string_literal: true

module Lab
  module Lims
    ##
    # Serialize a Lab::LabResult to LIMS' acknowledgement format
    module AcknowledgementSerializer
      class << self
        include Utils

        def serialize_acknowledgement(acknowledgement)
          serialized_acknowledgement = Lims::Utils.structify(acknowledgement)
          {
            tracking_number: Lab::LabOrder.find(serialized_acknowledgement.order_id).accession_number,
            test: ::ConceptName.where(concept_id: serialized_acknowledgement.test).first.name,
            date_acknowledged: format_date(serialized_acknowledgement.date_received),
            recipient_type: serialized_acknowledgement.acknowledgement_type
          }
        end

        private

        def format_date(date)
          date.strftime('%Y-%m-%d %H:%M:%S')
        end
      end
    end
  end
end
