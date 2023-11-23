class UserRole < ApplicationRecord
  self.table_name = :user_role
  self.primary_keys = :role, :user_id

  belongs_to :user, foreign_key: :user_id
  belongs_to :role, foreign_key: :role
end
