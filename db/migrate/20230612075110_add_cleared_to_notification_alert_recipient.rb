# frozen_string_literal: true

# this models is used to store the recipient of a notification alert and we have added a cleared column
# to indicate that the notification has been cleared by the user or a job
class AddClearedToNotificationAlertRecipient < ActiveRecord::Migration[5.2]
  def change
    add_column :notification_alert_recipient, :cleared, :boolean, default: false
  end
end
