# frozen_string_literal: true

# this model is used to store the actual notification alert
class NotificationAlert < ActiveRecord::Base
  before_create :check_uuid
  before_save :check_uuid

  self.table_name = :notification_alert
  self.primary_key = :alert_id

  belongs_to :creator, class_name: 'User', foreign_key: :creator
  belongs_to :changed_by, class_name: 'User', foreign_key: :changed_by

  has_many :notification_alert_recipients, class_name: 'NotificationAlertRecipient', foreign_key: :alert_id

  # create a scope to get records
  default_scope { where(alert_read: 0) }
  scope :alert_read, -> { unscoped.where.not(alert_read: 0) }

  def check_uuid
    self.uuid = SecureRandom.uuid if attributes.key?('uuid') && uuid.blank?
  end
end
