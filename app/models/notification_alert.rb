# frozen_string_literal: true

# this model is used to store the actual notification alert
class NotificationAlert < ApplicationRecord
  self.table_name = :notification_alert
  self.primary_key = :alert_id

  belongs_to :creator, class_name: 'User', foreign_key: :creator
  belongs_to :changed_by, class_name: 'User', foreign_key: :changed_by
end
