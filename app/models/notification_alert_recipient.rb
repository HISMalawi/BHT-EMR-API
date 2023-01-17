# frozen_string_literal: true

# this models is used to store the recipient of a notification alert
class NotificationAlertRecipient < ActiveRecord::Base
  before_create :check_uuid
  before_save :check_uuid

  self.table_name = :notification_alert_recipient
  self.primary_key = :alert_id

  belongs_to :notification_alert, foreign_key: :alert_id
  belongs_to :user, foreign_key: :user_id

  def check_uuid
    self.uuid = SecureRandom.uuid if attributes.has_key?('uuid') && uuid.blank?
  end
end
