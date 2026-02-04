class ConceptAttributeType < RetirableRecord
  self.table_name = :concept_attribute_type
  self.primary_key = :concept_attribute_type_id

  include Auditable
  include Voidable

  has_many :concept_attributes

  def self.nlims_code
    find_by_name('NLIMS CODE')
  end

  def self.test_catalogue_name
    find_by_name('TEST CATALOGUE NAME')
  end
end