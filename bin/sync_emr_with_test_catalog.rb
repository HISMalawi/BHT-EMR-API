require 'csv'
require 'logger'

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
User.current = User.first

csv_location = Rails.root.join('db', 'csv', 'test-catalog-x-concepts.csv')

def consolelog text
  puts "\n=======================================================\n"
  puts text
  puts "=======================================================\n"
end

def nlims_code_attribute_type
  # find or create the attribute type
  attribute_type = ConceptAttributeType.find_or_initialize_by(name: 'NLIMS CODE')
  return attribute_type unless attribute_type.new_record?

  attribute_type.description = 'NLIMS CODE'
  attribute_type.datatype = 'string'
  attribute_type.preferred_handler = 'org.openmrs.handler.concept.ConceptAttributeTypeHandler'
  attribute_type.min_occurs = 0
  attribute_type.max_occurs = 1
  attribute_type.save!
  
  attribute_type.reload
end

def nlims_test_catalogue_name
  # find or create the attribute type
  attribute_type = ConceptAttributeType.find_or_initialize_by(name: 'TEST CATALOGUE NAME')
  return attribute_type unless attribute_type.new_record?

  attribute_type.description = 'TEST CATALOGUE NAME'
  attribute_type.datatype = 'string'
  attribute_type.preferred_handler = 'org.openmrs.handler.concept.ConceptAttributeTypeHandler'
  attribute_type.min_occurs = 0
  attribute_type.max_occurs = 1
  attribute_type.save!
  
  attribute_type.reload
end

def test_type_concept_id
  ConceptName.find_by_name!('Test type').concept_id
end

def process(test_name, concept_id, test_catalog_name, nlims_code)
  concept = Concept.find_by(concept_id:)

  return unless nlims_code && concept.present?

  # set the nlims code as a concept attribute
  attribute = concept.concept_attributes.find_by(
    attribute_type: nlims_code_attribute_type,
    value_reference: nlims_code
  )

  unless attribute
    concept.concept_attributes.create!(
      attribute_type: nlims_code_attribute_type,
      value_reference: nlims_code
    )
  end

  attribute = concept.concept_attributes.find_by(
    attribute_type: nlims_test_catalogue_name,
    value_reference: test_catalog_name
  )

  unless attribute
    concept.concept_attributes.create!(
      attribute_type: nlims_test_catalogue_name,
      value_reference: test_catalog_name
    )
  end
end

def clear_duplicates
  duplicates = ConceptAttribute.where(
    attribute_type: nlims_test_catalogue_name
  ).group(:value_reference).having('count(*) > 1')

  duplicates.each do |duplicate|
    consolelog "Duplicate found for #{duplicate.value_reference}"

    # remove from concept_set all but one
    concept_attributes = ConceptAttribute.where(
      attribute_type: nlims_test_catalogue_name,
      value_reference: duplicate.value_reference
    )

    concept_attributes[1..].each do |attribute|
      ConceptSet.find_by(concept_id: attribute.concept_id, concept_set: test_type_concept_id)&.delete
      ConceptAttribute.find_by(concept_id: attribute.concept_id, attribute_type: nlims_test_catalogue_name)&.delete
    end
  end
end

# headers
# EMR Test Name	Test Catalog Name	NLIMS_Code	Concept_id
ActiveRecord::Base.transaction do
  CSV.foreach(csv_location, headers: true) do |row|
    test_name = row['EMR Test Name']
    concept_id = row['Concept_id']
    test_catalog_name = row['Test Catalog Name']
    nlims_code = row['NLIMS_Code']

    consolelog "Processing #{test_name}"

    process(test_name, concept_id, test_catalog_name, nlims_code)

    clear_duplicates
  end
end