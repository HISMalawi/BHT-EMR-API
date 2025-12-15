# frozen_string_literal: true

class PersonAttribute < VoidableRecord
  self.table_name = 'person_attribute'
  self.primary_key = 'person_attribute_id'

  include Locatable

  belongs_to(:type, class_name: 'PersonAttributeType',
             foreign_key: :person_attribute_type_id)
  belongs_to :person, foreign_key: :person_id

  def attribute_type_name
    type&.name
  end
end
