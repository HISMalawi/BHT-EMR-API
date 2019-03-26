# frozen_string_literal: true

class TimeService
  def current_time
    { time: Time.now.strftime('%H:%M:%S'), date: Date.today }
  end
end
