# frozen_string_literal: true

class UserProperty < ApplicationRecord
  self.table_name = 'user_property'
  self.primary_keys = %i[user_id property]

  belongs_to :user
end
