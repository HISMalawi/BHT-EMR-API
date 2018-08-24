class UserRole < ApplicationRecord
  self.table_name = :user_role
  self.primary_key = %i[role user_id]

  belongs_to :user
end
