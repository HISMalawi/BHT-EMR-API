# frozen_string_literal: true

require_relative './loader_mixin'

module Lab
  module Loaders
    module ReasonsForTestLoader
      class << self
        include LoaderMixin

        def load
          CSV.open(data_path('reasons-for-test.csv'), headers: :first_row) do |csv|
            csv.each do |row|
              puts "Adding reason for test: #{row['reason_name']}"
              add_concept_to_set(set_concept_id: find_or_create_concept(Lab::Metadata::REASON_FOR_TEST_CONCEPT_NAME).concept_id,
                                 concept_id: find_or_create_concept(row['reason_name']).concept_id)
            end
          end
        end
      end
    end
  end
end
