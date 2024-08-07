# frozen_string_literal: true

module Lab
  module Loaders
    module LoaderMixin
      def self.included(_mod)
        User.current = User.find_by_username('admin') || User.first
        Location.current = Location.find_by_name('Registration') || Location.first
      end

      CONCEPT_DATATYPE_CODED = 2
      CONCEPT_CLASS_TEST = 1

      def find_or_create_concept(name, is_set: false)
        # Filter out concept_names with voided concepts
        concept = ConceptName.joins(:concept).find_by_name(name)
        return concept if concept

        ConceptName.create!(
          concept: Concept.create!(
            short_name: name,
            datatype_id: CONCEPT_DATATYPE_CODED,
            class_id: CONCEPT_CLASS_TEST,
            is_set: is_set,
            uuid: SecureRandom.uuid,
            creator: User.current.user_id,
            date_created: Time.now
          ),
          name: name,
          locale: 'en',
          concept_name_type: 'FULLY_SPECIED',
          uuid: SecureRandom.uuid,
          creator: User.current.user_id,
          date_created: Time.now
        )
      end

      def add_concept_to_set(set_concept_id:, concept_id:)
        set = ConceptSet.find_by(concept_set: set_concept_id, concept_id: concept_id)
        return set if set

        ConceptSet.create!(concept_set: set_concept_id,
                           concept_id: concept_id,
                           creator: User.current.user_id,
                           date_created: Time.now)
      end

      def data_path(filename)
        "#{__dir__}/data/#{filename}"
      end
    end
  end
end
