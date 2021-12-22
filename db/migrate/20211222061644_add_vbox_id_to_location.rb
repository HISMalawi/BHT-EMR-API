# frozen_string_literal: true

# migration to add vbox id to location
class AddVboxIdToLocation < ActiveRecord::Migration[5.2]
  def up
    return if column_exists?(:location, :vbox_id)

    add_column :location, :vbox_id, :string
  end

  def down
    execute 'ALTER TABLE location DROP COLUMN vbox_id' if column_exists?(:location, :vbox_id)
  end
end
