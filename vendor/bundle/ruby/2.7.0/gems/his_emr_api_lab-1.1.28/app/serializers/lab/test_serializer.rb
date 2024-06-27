# frozen_string_literal: true

module Lab
  module TestSerializer
    def self.serialize(test, order: nil, result: nil)
      order ||= test.order
      result ||= test.result

      {
        id: test.obs_id,
        concept_id: test.value_coded,
        name: ConceptName.find_by_concept_id(test.value_coded)&.name,
        order: {
          id: order.order_id,
          concept_id: order.concept_id,
          name: ConceptName.find_by_concept_id(order.concept_id)&.name,
          accession_number: order.accession_number
        },
        result: if result
                  {
                    id: result.obs_id,
                    modifier: result.value_modifier,
                    value: result.value_text
                  }
                end
      }
    end
  end
end
