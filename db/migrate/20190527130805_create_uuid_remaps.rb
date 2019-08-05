class CreateUuidRemaps < ActiveRecord::Migration[5.2]
  def change
    create_table :uuid_remaps do |t|
      t.string :old_uuid
      t.string :new_uuid
      t.string :database
      t.string :model
      t.integer :record_id

      t.timestamps
      t.index :old_uuid
      t.index :new_uuid
      t.index :database
      t.index :model
      t.index %i[old_uuid new_uuid database model], name: 'index_all_fields'
    end
  end
end
