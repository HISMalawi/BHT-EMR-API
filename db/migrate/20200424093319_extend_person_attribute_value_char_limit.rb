class ExtendPersonAttributeValueCharLimit < ActiveRecord::Migration[5.2]
  def up
    change_column :person_attribute, :value, :string, limit: 120, null: false
  end

  def down
    change_column :person_attribute, :value, :string, limit: 50, null: false
  end
end
