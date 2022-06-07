# frozen_string_literal: true

# notification service
class NotificationService
  # this gets all unread notifications of the user
  def unread
    NotificationAlert.joins(:notification_alert_recipients).where(
      'notification_alert_recipient.user_id = ? AND notification_alert_recipient.alert_read = ?', User.current.user_id, false
    )
  end

  # this updates the notification to read
  def read(alerts)
    alerts.each do |alert|
      notification = NotificationAlertRecipient.where(user_id: User.current.user_id, alert_id: alert,
                                                      alert_read: false).first
      next if notification.blank?

      notification.alert_read = true
      notification.save
    end
  end

  def create_notification(_alert_type, alert_message)
    lab = User.find_by(username: 'lab_daemon')

    ActiveRecord::Base.transaction do
      alert = NotificationAlert.create!(text: alert_message, date_to_expire: Time.now + 3.months,
                                        creator: lab, changed_by: lab, date_created: Time.now)
      notify_all_users(alert)
      ActionCable.server.broadcast('nlims_channel', alert)
    end
  rescue StandardError
    Rails.logger.error('Error creating notification')
    Rails.logger.error($!.message)
    Rails.logger.error($!.backtrace.join("\n"))
  end

  def self.notify(notification_alert, recipients)
    recipients.each do |recipient|
      recipient.notification_alert_recipients.create(
        alert_id: notification_alert.id
      )
    end
  end

  def self.notify_all(notification_alert, users)
    users.each do |user|
      user.notification_alert_recipients.create(
        lert_id: notification_alert.id
      )
    end
  end

  def notify_all_users(notification_alert)
    User.all.each do |user|
      user.notification_alert_recipients.create!(
        alert_id: notification_alert.id
      )
    end
  end
end
