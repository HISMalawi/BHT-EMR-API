class DeleteLocationTypeId < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE location MODIFY COLUMN date_created DATETIME NOT NULL DEFAULT NOW()'
    remove_column :location, :location_type_id
  end
end
