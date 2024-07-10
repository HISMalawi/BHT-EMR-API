class AddRoleEntryForHsa < ActiveRecord::Migration[7.0]
  def change
    parent_role = 'Provider'
    child_role = 'Health Surveillance Assistant'
    description = "Immunization Community health worker"

    role = Role.create(role: child_role, description: description)

    RoleRole.create(parent_role: parent_role, child_role: role.role)

  end

end
