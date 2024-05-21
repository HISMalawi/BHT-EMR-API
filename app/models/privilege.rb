# frozen_string_literal: true

class Privilege < ApplicationRecord
  self.table_name = 'privilege'
  self.primary_key = 'privilege_id'

  has_many :role_privileges, foreign_key: :privilege, dependent: :delete_all
  has_many :roles, through: :role_privileges
end
