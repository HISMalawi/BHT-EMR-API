# frozen_string_literal: true

module Lab
  # Used to keep track of counters for accession numbers.
  #
  # An accession number is just a prefix plus a running encounter
  # that's reset at the end of the day
  class LabAccessionNumberCounter < ApplicationRecord
    self.table_name = :lab_accession_number_counters

    validates_presence_of :date, :value
  end
end
