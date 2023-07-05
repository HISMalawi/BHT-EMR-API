# frozen_string_literal: true

class Role < ApplicationRecord
  self.table_name = 'role'
  self.primary_key = 'role' # Yes, role is the name of the primary key

  # include Openmrs

  has_many :role_roles, foreign_key: :parent_role # A role has sub roles?
  has_many :role_privileges, foreign_key: :role, dependent: :delete_all
  has_many :privileges, through: :role_privileges, foreign_key: :role
  has_many :user_roles, foreign_key: :role, class_name: 'UserRole'
  has_many :roles, through: :user_roles, foreign_key: :role

  def self.setup_privileges_for_roles
    privileges = Privilege.all
    Role.all.each { |role| role.privileges << privileges }
  end
end
