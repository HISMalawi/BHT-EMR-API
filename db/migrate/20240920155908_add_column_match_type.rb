class AddColumnMatchType < ActiveRecord::Migration[7.0]
  def change
    add_column :potential_duplicates, :match_type, :string, length: 50 unless column_exists?(:potential_duplicates, :match_type)
  end
end
