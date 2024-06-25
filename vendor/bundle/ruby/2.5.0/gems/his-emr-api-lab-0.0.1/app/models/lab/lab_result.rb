# frozen_string_literal: true

module Lab
  class LabResult < Observation
    alias measures children

    default_scope do
      lab_test_concept = ConceptName.where(name: Lab::Metadata::TEST_RESULT_CONCEPT_NAME)
                                    .select(:concept_id)
      where(voided: 0, concept: lab_test_concept)
    end

    belongs_to :test,
               (lambda do
                  where(concept: ConceptName.where(name: Lab::Metadata::TEST_TYPE_CONCEPT_NAME)
                                            .select(:concept_id))
                end),
               class_name: 'Observation',
               foreign_key: :obs_group_id
  end
end
