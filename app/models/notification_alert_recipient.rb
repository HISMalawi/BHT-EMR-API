# frozen_string_literal: true

# this models is used to store the recipient of a notification alert
class NotificationAlertRecipient < ApplicationRecord
  self.table_name = :notification_alert_recipient
  self.primary_key = :alert_id

  belongs_to :notification_alert, foreign_key: :alert_id
  belongs_to :user, foreign_key: :user_id
end