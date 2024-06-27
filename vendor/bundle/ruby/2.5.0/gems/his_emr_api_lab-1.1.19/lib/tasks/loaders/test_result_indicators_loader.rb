# frozen_string_literal: true

require 'csv'
require_relative './loader_mixin'

module Lab
  module Loaders
    ##
    # Load specimens and their tests into the database
    module TestResultIndicatorsLoader
      class << self
        include LoaderMixin
      
        def load
          puts "------- Loading measures ------------"
          CSV.open(data_path('test-measures.csv'), headers: :first_row) do |csv|
            csv.each_with_object({}) do |row, test_measures|
              test_name = row['test_name']
              measure_name = row['measure_name']

              ActiveRecord::Base.transaction do
                measure_concept = find_or_create_concept(measure_name)
                add_measure_to_test(test_name, measure_concept)
              end

              puts "Created measure #{test_name} <--< #{measure_name}"
            rescue StandardError => e
              puts "Error: #{measure_name}: #{e}"
            end
          end
        end

        def create_test_type(name)
          concept_id = find_or_create_concept(name, is_set: true).concept_id

          create_concept_set(concept_set: test_type_concept_id, concept_id: concept_id)
        rescue StandardError => e
          raise "Failed to create test type `#{name}`: #{e}"
        end

        def add_measure_to_test(test_name, measure_concept)
          [
            add_concept_to_set(set_concept_id: find_or_create_concept(Lab::Metadata::TEST_RESULT_INDICATOR_CONCEPT_NAME).concept_id,
                               concept_id: measure_concept.concept_id),
            add_concept_to_set(set_concept_id: measure_concept.concept_id,
                               concept_id: find_or_create_concept(test_name).concept_id)
          ]
        rescue StandardError => e
          raise "Failed to create measure for test `#{name}`: #{e}"
        end
      end
    end
  end
end
