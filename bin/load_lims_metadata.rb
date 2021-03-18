# frozen_string_literal: true

require 'csv'

if $ARGV.size != 1
  puts 'Error: No metadata file specified'
  puts 'Usage: rails r bin/load_lims_metadata.rb lims-metadata.csv'
  exit
end

User.current = User.first
Location.current = Location.first

def test_type_concept_id
  @test_type_concept_id ||= ConceptName.find_by_name!('Test type').concept_id
end

def sample_type_concept_id
  @sample_type_concept_id ||= ConceptName.find_by_name!('Specimen type').concept_id
end

CONCEPT_DATATYPE_CODED = 2
CONCEPT_CLASS_TEST = 1

def concept(name, is_set: false)
  # Filter out concept_names with voided concepts
  concept = ConceptName.joins(:concept).find_by_name(name)
  return concept if concept

  ConceptName.create!(
    concept: Concept.create!(
      short_name: name,
      datatype_id: CONCEPT_DATATYPE_CODED,
      class_id: CONCEPT_CLASS_TEST,
      is_set: is_set,
      uuid: SecureRandom.uuid,
      creator: User.current.user_id,
      date_created: Time.now
    ),
    name: name,
    locale: 'en',
    concept_name_type: 'FULLY_SPECIED',
    uuid: SecureRandom.uuid,
    creator: User.current.user_id,
    date_created: Time.now
  )
end

def create_concept_set(concept_set:, concept_id:)
  set = ConceptSet.find_by(concept_set: concept_set, concept_id: concept_id)
  return set if set

  ConceptSet.create!(concept_set: concept_set,
                     concept_id: concept_id,
                     creator: User.current.user_id,
                     date_created: Time.now)
end

def create_test_type(name)
  concept_id = concept(name, is_set: true).concept_id

  create_concept_set(concept_set: test_type_concept_id, concept_id: concept_id)
rescue StandardError => e
  raise "Failed to create test type `#{name}`: #{e}"
end

def create_sample_type(name, test_type)
  concept_id = concept(name).concept_id

  [
    create_concept_set(concept_set: sample_type_concept_id, concept_id: concept_id),
    create_concept_set(concept_set: test_type.concept_id, concept_id: concept_id)
  ]
rescue StandardError => e
  raise "Failed to create sample type `#{name}`: #{e}"
end

CSV.open(Rails.root.join($ARGV[0]), headers: :first_row) do |csv|
  test_types = {}

  csv.each do |row|
    test_type_name = row[1]
    sample_type_name = row[0]

    ActiveRecord::Base.transaction do
      test_type = test_types[test_type_name] || create_test_type(test_type_name)
      create_sample_type(sample_type_name, test_type)

      test_types[test_type_name] ||= test_type
    end

    puts "Created test #{test_type_name} <--< #{sample_type_name}"
  rescue StandardError => e
    puts "Error: #{test_type_name}: #{e}"
  end
end
