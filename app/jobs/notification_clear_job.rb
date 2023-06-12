# frozen_string_literal: true

# this job is used to clear notifications after a certain period of time has elapsed
class NotificationClearJob < ApplicationJob
  queue_as :default

  def perform
    lab = User.find_by(username: 'lab_daemon')
    NotificationAlert.where('date_to_expire < ?', Time.now).each do |alert|
      # update the notification alert to read
      alert.update!(alert_read: true, changed_by: lab)
      # update the notification alert recipient to cleared
      alert.notification_alert_recipients.update_all(cleared: true, alert_read: true)
    end
  end
end
