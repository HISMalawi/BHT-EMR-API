require 'composite_primary_keys'

class RolePrivilege < ApplicationRecord
  self.table_name = 'role_privilege'
  self.primary_keys = %i[privilege role]

  belongs_to :role, foreign_key: :role
  belongs_to :privilege, foreign_key: :privilege
end
