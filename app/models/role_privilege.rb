# frozen_string_literal: true

class RolePrivilege < ApplicationRecord
  self.table_name = 'role_privilege'
  self.primary_key = %i[privilege role]

  belongs_to :role, foreign_key: :role
  belongs_to :privilege, foreign_key: :privilege
end
