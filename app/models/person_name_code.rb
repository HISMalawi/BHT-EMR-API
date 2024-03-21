# frozen_string_literal: true

class PersonNameCode < ApplicationRecord
  self.table_name = 'person_name_code'
  self.primary_key = 'person_name_code_id'

  belongs_to :person_name
end
