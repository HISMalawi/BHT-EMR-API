# frozen_string_literal: true

require 'csv'

if $ARGV.size != 1
  puts 'Error: No metadata file specified'
  puts 'Usage: rails r bin/load_lims_metadata.rb lims-metadata.csv'
end

User.current = User.first
Location.current = Location.first

def test_type_concept_id
  @test_type_concept_id ||= ConceptName.find_by_name!('Test type').concept_id
end

def sample_type_concept_id
  @sample_type_concept_id ||= ConceptName.find_by_name!('Specimen type').concept_id
end

def create_test_type(name)
  concept_id = ConceptName.find_by_name!(name).concept_id

  ConceptSet.find_or_create_by!(concept_set: test_type_concept_id,
                                concept_id: concept_id,
                                creator: User.current.user_id)
rescue StandardError => e
  raise "Failed to create test type `#{name}`: #{e}"
end

def create_sample_type(name, test_type)
  concept_id = ConceptName.find_by_name!(name).concept_id

  [
    ConceptSet.find_or_create_by!(concept_set: sample_type_concept_id,
                                  concept_id: concept_id,
                                  creator: User.current.user_id),
    ConceptSet.find_or_create_by!(concept_set: test_type.concept_id,
                                  concept_id: concept_id,
                                  creator: User.current.user_id)
  ]
rescue StandardError => e
  raise "Failed to create sample type `#{name}`: #{e}"
end

CSV.open(Rails.root.join($ARGV[0]), headers: :first_row) do |csv|
  test_types = {}

  csv.each do |row|
    test_type_name = row[0]
    sample_type_name = row[1]

    ActiveRecord::Base.transaction do
      test_type = test_types[test_type] || create_test_type(test_type_name)
      create_sample_type(sample_type_name, test_type)

      test_types[test_type] ||= test_type
    end
  rescue StandardError => e
    puts "Error: #{test_type_name}: #{e}"
  end
end
