module ImmunizationService
  module SendSmsService
  def self.perform_async(date, details)
     
    reminder = ENV['SMS_REMINDER']
    period = ENV['NEXT_APPOINTMENT_REMINDER_PERIOD']
    notifications = ENV['SMS_ACTIVATION']
    if(reminder == true){
       days_before = period.split(" ")[0].to_i
       reminder_date = Date.parse(date) - days_before
       reminder_time = reminder_date.to_time
       SendSmsJob.set(wait_until: reminder_time).perform_later(date, details)
    }
    
    SendSmsJob.perform_later(date, details) if notifications == true
    
  end
  end
end
