# frozen_string_literal: true

module Lab
  class LabTest < ::Observation
    default_scope do
      where(concept: ConceptName.where(name: Lab::Metadata::TEST_TYPE_CONCEPT_NAME))
    end

    has_one :result,
            -> { where(concept: ConceptName.where(name: Lab::Metadata::TEST_RESULT_CONCEPT_NAME)) },
            class_name: '::Lab::LabResult',
            foreign_key: :obs_group_id

    def void(reason)
      result&.void(reason)
      super(reason)
    end
  end
end
