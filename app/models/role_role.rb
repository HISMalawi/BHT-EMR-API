# frozen_string_literal: true

require 'composite_primary_keys'
class RoleRole < ApplicationRecord
  self.table_name = 'role_role'
  self.primary_keys = :parent_role, :child_role
end
