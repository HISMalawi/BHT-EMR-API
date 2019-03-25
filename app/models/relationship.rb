# frozen_string_literal: true

class Relationship < VoidableRecord
  self.table_name = :relationship
  self.primary_key = :relationship_id

  belongs_to :person, class_name: 'Person', foreign_key: :person_a,
                      optional: true
  belongs_to :relation, class_name: 'Person', foreign_key: :person_b,
                        optional: true
  belongs_to :type, class_name: 'RelationshipType', foreign_key: :relationship,
                    optional: true

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
