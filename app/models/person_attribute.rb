class PersonAttribute < VoidableRecord
  self.table_name = 'person_attribute'
  self.primary_key = 'person_attribute_id'

  belongs_to(:type, class_name: 'PersonAttributeType',
                    foreign_key: :person_attribute_type_id)

  belongs_to :person, foreign_key: :person_id
end
