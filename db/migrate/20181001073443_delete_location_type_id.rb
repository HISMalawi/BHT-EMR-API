class DeleteLocationTypeId < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE location MODIFY COLUMN date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()'
    remove_column :location, :location_type_id
  end
end
