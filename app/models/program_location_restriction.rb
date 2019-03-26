# frozen_string_literal: true

class ProgramLocationRestriction < ApplicationRecord
  self.table_name = 'program_location_restriction'
  self.primary_key = 'program_location_restriction_id'

  belongs_to :program
  belongs_to :location
end
