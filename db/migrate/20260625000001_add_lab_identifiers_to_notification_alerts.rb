# frozen_string_literal: true

# Migration to add lab-specific identifiers to notification_alerts table
# and create a unique composite index to prevent duplicate notifications
class AddLabIdentifiersToNotificationAlerts < ActiveRecord::Migration[5.2]
  def change
    # Add columns for lab notification uniqueness
    add_column :notification_alert, :test_type_id, :integer, null: true unless column_exists?(:notification_alert,
                                                                                              :test_type_id)
    add_column :notification_alert, :order_id, :integer, null: true unless column_exists?(:notification_alert,
                                                                                          :order_id)
    add_column :notification_alert, :specimen_id, :integer, null: true unless column_exists?(:notification_alert,
                                                                                             :specimen_id)

    # Add foreign key constraints
    unless foreign_key_exists?(
      :notification_alert, column: :test_type_id
    )
      add_foreign_key :notification_alert, :concept_name, column: :test_type_id,
                                                          primary_key: :concept_id
    end
    add_foreign_key :notification_alert, :orders, column: :order_id, primary_key: :order_id unless foreign_key_exists?(
      :notification_alert, column: :order_id
    )
    # NOTE: specimen_id doesn't have a foreign key as it may reference external LIMS specimen IDs

    # Add unique composite index to prevent duplicate notifications
    # This ensures that for any combination of test_type_id, order_id, and specimen_id,
    # only one notification can exist
    add_index :notification_alert,
              %i[test_type_id order_id specimen_id],
              unique: true,
              name: 'idx_notification_alert_lab_unique',
              where: 'test_type_id IS NOT NULL AND order_id IS NOT NULL AND specimen_id IS NOT NULL'

    # Add individual indexes for query performance
    add_index :notification_alert, :test_type_id, name: 'idx_notification_alert_test_type' unless index_exists?(
      :notification_alert, :test_type_id, name: 'idx_notification_alert_test_type'
    )
    add_index :notification_alert, :order_id, name: 'idx_notification_alert_order' unless index_exists?(
      :notification_alert, :order_id, name: 'idx_notification_alert_order'
    )
    add_index :notification_alert, :specimen_id, name: 'idx_notification_alert_specimen' unless index_exists?(
      :notification_alert, :specimen_id, name: 'idx_notification_alert_specimen'
    )
  end
end
