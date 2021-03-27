class PersonRelationshipService
  def initialize(person)
    @person = person
  end

  def get_relationship(relationship_id)
    relationship = Relationship.find_by relationship_id: relationship_id,
                                        person_a: @person.person_id
    raise NotFoundError, 'Relationship not found' unless relationship
    relationship
  end

  def void_relationship(relationship_id, reason)
    get_relationship(relationship_id).void(reason)
  end

  def find_relationships(filters)
    relationships = Relationship.where 'person_a = :person', person: @person.person_id
    relationships = relationships.where filters unless filters.empty?
    relationships
  end

  def find_guardians
    Relationship.joins(:type).where 'person_a = ? AND b_is_to_a = ?',
                                    @person.person_id,
                                    'Guardian'
  end

  def create_relationship(person, relationship_type)
    Relationship.create person: @person,
                        relation: person,
                        type: relationship_type
  end
end
