# frozen_string_literal: true

# Migration to add a column to the encounter table
class AddProgramIdToEncounter < ActiveRecord::Migration[5.2]
  def up
    add_column :encounter, :uuid, :string, limit: 38, null: true unless column_exists?(:encounter, :uuid)
    add_column :encounter, :changed_by, :integer, null: true unless column_exists?(:encounter, :changed_by)
    add_column :encounter, :date_changed, :datetime, null: true unless column_exists?(:encounter, :date_changed)
    add_column :encounter, :program_id, :integer, default: 1 unless column_exists?(:encounter, :program_id)

    # generate uuids for existing records
    # Encounter.all.each do |encounter|
    #   encounter.uuid = SecureRandom.uuid
    #   encounter.save
    # end
    
    # alter column to not allow null
    # change_column :encounter, :uuid, :string, limit: 38, null: false unless column_exists?(:encounter, :uuid)

    # add foreign key
    add_foreign_key :encounter, :program, column: :program_id, foreign_key: :program_id, primary_key: :program_id unless foreign_key_exists?(:encounter, :program)
    # uuid has to be unique
    # add_index :encounter, :uuid, unique: true unless index_exists?(:encounter, :uuid)
  end

  def down
    remove_column :encounter, :uuid
    remove_column :encounter, :changed_by
    remove_column :encounter, :date_changed
    remove_column :encounter, :program_id
  end
end
