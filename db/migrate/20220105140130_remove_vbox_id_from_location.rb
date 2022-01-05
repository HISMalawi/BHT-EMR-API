# frozen_string_literal:true

# migration to reverse vbox mapping
class RemoveVboxIdFromLocation < ActiveRecord::Migration[5.2]
  def change
    remove_column :location, :vbox_id, :string
  end
end
