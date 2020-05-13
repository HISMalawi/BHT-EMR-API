class DeleteLocationTypeId < ActiveRecord::Migration[5.2]
  def change
    execute 'ALTER TABLE location MODIFY COLUMN date_created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP()'
    execute 'ALTER TABLE location DROP COLUMN location_type_id' rescue 'Does not exisits'
  end
end
