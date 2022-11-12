class CreateLimsAcknowledgementStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :lims_acknowledgement_statuses, id: false do |t|
      t.string :tracking_number, primary_key: true
      t.string :test_name, null: false
      t.string :date_acknowledged, null: false
      t.string :acknowledgment_type, null: false
      t.boolean :status, null: false, default: false
    end
  end
end
