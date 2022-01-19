# frozen_string_literal: true

# adding migration to create urine lam indicator
class AddUrineLamIndicator < ActiveRecord::Migration[5.2]
  # insert lam as indicator here
  def up
    concept = Concept.create(short_name: 'Lam', datatype_id: 3, class_id: 11, is_set: 0, creator: User.first.id, date_created: Time.now, uuid: SecureRandom.uuid)
    ConceptName.create(name: concept.short_name, locale: 'en', creator: concept.creator, date_created: concept.date_created, concept_id: concept.concept_id, uuid: SecureRandom.uuid, concept_name_type: 'FULLY_SPECIED', locale_preferred: 0)
    # fetch concept id for lab indicator and Urine Lam
    indicator = ConceptName.find_by name: 'Lab test result indicator'
    test_type = ConceptName.find_by name: 'Urine Lam'
    # add lam as indicator
    ConceptSet.create(concept_id: concept.concept_id, concept_set: indicator.concept_id, creator: concept.creator, date_created: concept.date_created, uuid: SecureRandom.uuid)
    # adding lam to the test type of Urine Lam
    ConceptSet.create(concept_id: test_type.concept_id, concept_set: concept.concept_id, creator: concept.creator, date_created: concept.date_created, uuid: SecureRandom.uuid)
  end

  # method reverse inserting lam indicator here
  def down
    # fetch
    indicator = ConceptName.find_by name: 'Lab test result indicator'
    test_type = ConceptName.find_by name: 'Urine Lam'
    concept = Concept.find_by short_name: 'Lam'
    concept_name = ConceptName.find_by concept_id: concept.concept_id
    concept_set_indicator = ConceptSet.find_by concept_id: concept.concept_id, concept_set: indicator.concept_id
    concept_set_type = ConceptSet.find_by concept_id: test_type.concept_id, concept_set: concept.concept_id

    # void
    message = 'Voided by migration reversal'
    concept_set_type.destroy
    concept_set_indicator.destroy
    concept_name.void message
    concept.void message
  end
end
