class CreateUserPrograms < ActiveRecord::Migration[5.2]
  def change
    create_table :user_programs do |t|
      t.belongs_to :user, limit: 11
      t.belongs_to :program, limit: 11
      t.integer :voided, default: 0
      t.string :void_reason, null: true
      t.timestamps
    end
  end
end