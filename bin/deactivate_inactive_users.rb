# frozen_string_literal: true

require 'logger'

LOGGER = Logger.new(File.join(Rails.root, 'log', 'cron.log'))
ActiveRecord::Base.logger = LOGGER

def main
  superuser = User.joins(:user_roles).where(user_roles: { role: 'Superuser'} ).order(date_changed: :desc).first
  labdaemon = User.find_by(username: 'lab_daemon')

  # get the password expiry days
  password_expiry_days = GlobalProperty.find_by_property('password_reset_interval')&.property_value&.to_i || 90
  LOGGER.info("Deactivating users with no activity in the last #{password_expiry_days} days")

  User.where(date_changed: ..password_expiry_days.days.ago)
      .where.not(id: [superuser.id, labdaemon.id])
      .update_all(deactivated_on: Time.now)

  superuser.update!(deactivated_on: nil)
end

main
