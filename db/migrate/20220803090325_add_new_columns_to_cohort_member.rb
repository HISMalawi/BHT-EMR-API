class AddNewColumnsToCohortMember < ActiveRecord::Migration[5.2]
  def up
    execute 'ALTER TABLE `cohort_member` DROP PRIMARY KEY'
    add_column :cohort_member, :cohort_member_id, :integer, primary_key: true
    add_column :cohort_member, :start_date, :datetime, null: false
    add_column :cohort_member, :end_date, :datetime, null: true
    add_column :cohort_member, :creator, :integer, null: false
    add_column :cohort_member, :date_created, :datetime, null: false
    add_column :cohort_member, :voided, :boolean, default: false, null: false
    add_column :cohort_member, :voided_by, :integer, null: true
    add_column :cohort_member, :date_voided, :datetime, null: true
    add_column :cohort_member, :void_reason, :string, null: true
    add_column :cohort_member, :uuid, :string, null: false, unique: true, limit: 38
    add_foreign_key :cohort_member, :users, column: :creator, primary_key: :user_id
    add_foreign_key :cohort_member, :users, column: :voided_by, primary_key: :user_id
  end

  def down
    remove_foreign_key :cohort_member, column: :creator, primary_key: :user_id
    remove_foreign_key :cohort_member, column: :voided_by, primary_key: :user_id
    remove_column :cohort_member, :cohort_member_id
    remove_column :cohort_member, :start_date
    remove_column :cohort_member, :end_date
    remove_column :cohort_member, :creator
    remove_column :cohort_member, :date_created
    remove_column :cohort_member, :voided
    remove_column :cohort_member, :voided_by
    remove_column :cohort_member, :date_voided
    remove_column :cohort_member, :void_reason
    remove_column :cohort_member, :uuid
    execute 'ALTER TABLE `cohort_member` ADD PRIMARY KEY (`cohort_id`, `patient_id`)'
  end
end
