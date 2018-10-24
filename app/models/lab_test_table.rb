# frozen_string_literal: true

class LabTestTable < ApplicationRecord
  self.table_name = 'LabTestTable'
  self.primary_key = 'AccessionNum'

  use_healthdata_db
end
