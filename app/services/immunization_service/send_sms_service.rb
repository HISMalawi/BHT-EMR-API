module SendSmsService
  def self.perform_async(date, details)
     
    period = ENV['NEXT_APPOINTMENT_REMINDER_PERIOD']
    SendSmsJob.perform_later(date, details) if period == 'Instant reminder'
    days_before = period.split(" ")[0].to_i
    reminder_date = Date.parse(date) - days_before
    reminder_time = reminder_date.to_time
    SendSmsJob.set(wait_until: reminder_time).perform_later(date, details)

  end
end
