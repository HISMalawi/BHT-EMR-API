# frozen_string_literal: true

# notification service
class NotificationService
  # this gets all uncleared notifications of the user
  def uncleared
    NotificationAlert.joins(:notification_alert_recipients).where(
      'notification_alert_recipient.user_id = ?', User.current.user_id
    )
  end

  def clear(alert_id)
    alert = NotificationAlert.find(alert_id)
    # update the notification alert recipient to cleared and read only for the current user
    alert.notification_alert_recipients.where(user_id: User.current.user_id).update_all(cleared: true, alert_read: true)
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

  def create_notification(alert_type, alert_message)
    return if alert_type != 'LIMS'

    lab = User.find_by(username: 'lab_daemon')
    clear_notifications
    ActiveRecord::Base.transaction do
      alert = NotificationAlert.create!(text: alert_message.to_json, date_to_expire: Time.now + not_period.days,
                                        creator: lab, changed_by: lab, date_created: Time.now)
      notify(alert, User.joins(:roles).uniq)
      # ActionCable.server.broadcast('nlims_channel', alert)
    end
  end

  def not_period
    result = GlobalProperty.where(property: 'notification_period')&.first
    return result.property_value.to_i if result.present?

    7 # default to 7 days
  end

  def notify(notification_alert, recipients)
    recipients.each do |recipient|
      recipient.notification_alert_recipients.create(
        alert_id: notification_alert.id
      )
    end
  end

  def notify_all(notification_alert, users)
    users.each do |user|
      user.notification_alert_recipients.create(
        alert_id: notification_alert.id
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

  def clear_notifications
    NotificationClearJob.perform_later
  end
end
