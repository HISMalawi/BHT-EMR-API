# frozen_string_literal: true

# this models is used to store the recipient of a notification alert
class NotificationAlertRecipient < ActiveRecord::Base
  before_create :check_uuid
  before_save :check_uuid

  self.table_name = :notification_alert_recipient
  self.primary_key = :alert_id

  belongs_to :notification_alert, foreign_key: :alert_id
  belongs_to :user, foreign_key: :user_id

  # create a scope to get records
  default_scope { where(cleared: 0) }
  scope :cleared, -> { unscoped.where.not(cleared: 0) }

  def check_uuid
    self.uuid = SecureRandom.uuid if attributes.key?('uuid') && uuid.blank?
  end
end
