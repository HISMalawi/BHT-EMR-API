module ImmunizationService
  module SendSmsService
    def self.perform_async(date, details)
      reminder = fetch_global_property('sms_reminder') || ENV['SMS_REMINDER']
      period = fetch_global_property('next_appointment_reminder_period') || ENV['NEXT_APPOINTMENT_REMINDER_PERIOD']
      notifications = fetch_global_property('sms_activation') || ENV['SMS_ACTIVATION']
      
      if reminder == 'true'
        days_before = period.split(" ")[0].to_i
        reminder_date = Date.parse(date) - days_before
        reminder_time = reminder_date.to_time
        SendSmsJob.set(wait_until: reminder_time).perform_later(date, details)
      end
      
      SendSmsJob.perform_later(date, details) if notifications == 'true'
    end

    def self.fetch_global_property(key)
      GlobalProperty.find_by(property: "#{User.current.location_id}_#{key}")&.property_value
    end
  end
end
