# frozen_string_literal: true

# This migration comes from lab (originally 20260119104241)
# This migration creates the concept for the comment to fulfiller feature.
class CreateCommentToFulfillerConcept < ActiveRecord::Migration[5.2]
  def up
    # Return if the concept already exists
    return if ConceptName.exists?(name: 'Comment to fulfiller')

    ActiveRecord::Base.transaction do
      # Find or create the concept class for Misc
      concept_class = ConceptClass.find_by(name: 'Finding')

      # Find or create the concept datatype for Text
      concept_datatype = ConceptDatatype.find_by(name: 'Text')

      # Create the concept
      concept = Concept.create!(
        class_id: concept_class.id,
        datatype_id: concept_datatype.id,
        short_name: 'Comment to fulfiller',
        retired: 0,
        is_set: 0,
        creator: 1,
        date_created: Time.current,
        uuid: SecureRandom.uuid
      )

      # Create the concept name
      ConceptName.create!(
        concept: concept,
        name: 'Comment to fulfiller',
        locale: 'en',
        locale_preferred: 1,
        concept_name_type: 'FULLY_SPECIFIED',
        creator: 1,
        date_created: Time.current,
        uuid: SecureRandom.uuid
      )
      puts "Created 'Comment to fulfiller' concept with ID: #{concept.concept_id}"
    end
  end

  def down
    concept = ConceptName.find_by(name: 'Comment to fulfiller')&.concept
    return unless concept

    ConceptName.where(concept: concept).destroy_all
    concept.destroy
  end
end
