# frozen_string_literal: true

class CreateUuidRemaps < ActiveRecord::Migration[5.2]
  def change
    create_table :uuid_remaps do |t|
      t.string :old_uuid
      t.string :new_uuid
      t.string :database
      t.string :model
      t.integer :record_id

      t.timestamps
      # t.index :old_uuid
      # t.index :new_uuid
      # t.index :database
      # t.index :model
      # t.index %i[old_uuid new_uuid database model], name: 'index_all_fields'
    end

    # create an index
    # add_index :uuid_remaps, %i[old_uuid new_uuid database model], name: 'index_all_fields'
    add_index :uuid_remaps, :old_uuid, name: 'index_old_uuid'
    add_index :uuid_remaps, :new_uuid, name: 'index_new_uuid'
    add_index :uuid_remaps, :database, name: 'index_database'
    add_index :uuid_remaps, :model, name: 'index_model'
  end
end
