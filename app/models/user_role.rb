require 'composite_primary_keys'

class UserRole < ApplicationRecord
  self.table_name = :user_role
  self.primary_keys = [:role, :user_id]

  belongs_to :user
  belongs_to :role, primary_key: :role
end
