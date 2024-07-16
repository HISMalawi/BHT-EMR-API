class AddRelationshipHsaToProviderMapping < ActiveRecord::Migration[7.0]
  def change
    parent_role = 'Provider'
    child_role = 'HSA'
    
    RoleRole.create(parent_role: parent_role, child_role: child_role)
  end
end