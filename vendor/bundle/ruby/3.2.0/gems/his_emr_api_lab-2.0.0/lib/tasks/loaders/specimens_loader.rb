# frozen_string_literal: true

require 'csv'
require_relative 'loader_mixin'

module Lab
  module Loaders
    ##
    # Load specimens and their tests into the database
    module SpecimensLoader
      class << self
        include LoaderMixin

        def load
          puts '------- Loading tests and specimens ---------'
          CSV.open(data_path('tests.csv'), headers: :first_row) do |csv|
            csv.each_with_object({}) do |row, test_types|
              specimen_name = row['specimen_name']
              test_name = row['test_name']

              ActiveRecord::Base.transaction do
                test_type = test_types[test_name] || create_test_type(test_name)
                create_specimen_type(specimen_name, test_type)

                test_types[test_name] ||= test_type
              end

              puts "Created test #{test_name} <--< #{specimen_name}"
            rescue StandardError => e
              puts "Error: #{test_name}: #{e}"
            end
          end
        end

        def test_type_concept_id
          find_or_create_concept(Lab::Metadata::TEST_TYPE_CONCEPT_NAME).concept_id
        end

        def specimen_type_concept_id
          find_or_create_concept(Lab::Metadata::SPECIMEN_TYPE_CONCEPT_NAME).concept_id
        end

        def create_test_type(name)
          concept_id = find_or_create_concept(name, is_set: true).concept_id

          add_concept_to_set(set_concept_id: test_type_concept_id, concept_id:)
        rescue StandardError => e
          raise "Failed to create test type `#{name}`: #{e}"
        end

        def create_specimen_type(name, test_type)
          concept_id = find_or_create_concept(name).concept_id

          [
            add_concept_to_set(set_concept_id: specimen_type_concept_id, concept_id:),
            add_concept_to_set(set_concept_id: test_type.concept_id, concept_id:)
          ]
        rescue StandardError => e
          raise "Failed to create specimen type `#{name}`: #{e}"
        end
      end
    end
  end
end
