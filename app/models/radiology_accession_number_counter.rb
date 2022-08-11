# frozen_string_literal: true

# Used to keep track of the current accession number
#
# An accession number is a unique identifier for a particular hospital order
class RadiologyAccessionNumberCounter < ApplicationRecord
  self.table_name = :radiology_accession_number_counters

  validates_presence_of :date, :value
end
