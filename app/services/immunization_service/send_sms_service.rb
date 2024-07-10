module SendSmsService
  def self.perform_async(date, details)
    SendSmsJob.perform_later(date, details)
  end
end
