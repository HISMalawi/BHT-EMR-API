class PersonAttribute < ActiveRecord::Base
  self.table_name = 'person_attribute'
  self.primary_key = 'person_attribute_id'

  belongs_to(:type, class_name: 'PersonAttributeType',
                    foreign_key: :person_attribute_type_id)

  belongs_to :person, foreign_key: :person_id

  # def self.phone_numbers(person_id)
  #   home_phone_id       = PersonAttributeType.find_by_name('HOME PHONE NUMBER').person_attribute_type_id
  #   cell_phone_id       = PersonAttributeType.find_by_name('CELL PHONE NUMBER').person_attribute_type_id
  #   office_phone_id     = PersonAttributeType.find_by_name('OFFICE PHONE NUMBER').person_attribute_type_id

  #   phone_number_query  = "SELECT person_attribute_type.name AS attribute_type, person_attribute.value
  #                           FROM  person_attribute, person_attribute_type
  #                           WHERE person_attribute_type.person_attribute_type_id = person_attribute.person_attribute_type_id
  #                           AND   person_attribute.person_attribute_type_id IN (#{home_phone_id}, #{cell_phone_id},#{office_phone_id})
  #                           AND   person_id = #{person_id}"

  #   phone_number_objects = PersonAttribute.find_by_sql(phone_number_query)

  #   # create a hash of 'symbols' and 'values' like:
  #   #   {cell_phone_number => '0123456789', home_phone_number => '0987654321'}
  #   person_phone_numbers = phone_number_objects.reduce({}) do |result, number|
  #     attribute_type          = number.attribute_type.downcase.gsub(" ", "_").to_sym
  #     result[attribute_type]  = number.value
  #     result
  #   end

  #   person_phone_numbers
  # end
end
