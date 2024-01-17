class CreateMohRegimenNames < ActiveRecord::Migration[5.2]
  def change
    return if table_exists?(:moh_regimen_name)

    create_table :moh_regimen_name, id: false do |t|
      t.integer :regimen_name_id, primary_key: true
      t.string :name, null: false

      t.timestamps
    end
  end
end
