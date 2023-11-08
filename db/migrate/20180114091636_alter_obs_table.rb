# frozen_string_literal: true

# this migration alters the obs table to change in the following columns:
class AlterObsTable < ActiveRecord::Migration[5.2]
  def up
    # add value_complex and uuid columns if they dont exists
    add_column :obs, :value_complex, :string unless column_exists?(:obs, :value_complex)

    add_column :obs, :uuid, :string, length: 38 unless column_exists?(:obs, :uuid)
  end

  def down
    remove_column obs, :value_complex
    remove_column obs, :uuid
  end
end
