# frozen_string_literal: true

module Lab
  module LabOrderSerializer
    def self.serialize_order(order, tests: nil, requesting_clinician: nil, reason_for_test: nil, target_lab: nil)
      tests ||= order.voided == 1 ? voided_tests(order) : order.tests
      requesting_clinician ||= order.requesting_clinician
      reason_for_test ||= order.reason_for_test
      target_lab = target_lab&.value_text || order.target_lab&.value_text || Location.current_health_center&.name

      ActiveSupport::HashWithIndifferentAccess.new(
        {
          id: order.order_id,
          order_id: order.order_id, # Deprecated: Link to :id
          encounter_id: order.encounter_id,
          order_date: order.start_date,
          patient_id: order.patient_id,
          accession_number: order.accession_number,
          specimen: {
            concept_id: order.concept_id,
            name: concept_name(order.concept_id)
          },
          requesting_clinician: requesting_clinician&.value_text,
          target_lab: target_lab,
          reason_for_test: {
            concept_id: reason_for_test&.value_coded,
            name: concept_name(reason_for_test&.value_coded)
          },
          tests: tests.map do |test|
            result_obs = test.children.first

            {
              id: test.obs_id,
              concept_id: test.value_coded,
              name: concept_name(test.value_coded),
              result: result_obs && ResultSerializer.serialize(result_obs)
            }
          end
        }
      )
    end

    def self.concept_name(concept_id)
      return concept_id unless concept_id

      ConceptName.select(:name).find_by_concept_id(concept_id)&.name
    end

    def self.voided_tests(order)
      concept = ConceptName.where(name: Lab::Metadata::TEST_TYPE_CONCEPT_NAME)
                           .select(:concept_id)
      LabTest.unscoped.where(concept: concept, order: order, voided: true)
    end
  end
end
