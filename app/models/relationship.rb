# frozen_string_literal: true

class Relationship < VoidableRecord
  self.table_name = :relationship
  self.primary_key = :relationship_id

  include Locatable

  belongs_to :person, class_name: 'Person', foreign_key: :person_a,
                      optional: true
  belongs_to :relation, class_name: 'Person', foreign_key: :person_b,
                        optional: true
  belongs_to :type, class_name: 'RelationshipType', foreign_key: :relationship,
                    optional: true

  # Scope for bidirectional relationship search
  scope :for_person, ->(person_id) {
    where('person_a = :person OR person_b = :person', person: person_id)
  }

  # Get the "other" person in the relationship
  def other_person(current_person_id)
    person_a == current_person_id ? relation : person
  end

  # Check if this relationship is reversed for a given person
  def reverse_for?(person_id)
    person_b == person_id
  end

  def as_json(options = {})
    super(options.merge(
      include: {
        type: {},
        relation: {
          include: {
            names: {},
            person_attributes: { include: :type },
            addresses: {}
          }
        }
      }
    ))
  end
end