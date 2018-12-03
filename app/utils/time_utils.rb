# frozen_string_literal: true

module TimeUtils
  class << self
    def time_epoch
      Time.now - 120.years
    end

    def date_epoch
      Date.today - 120.years
    end

    # Returns a 24 hour period (day) containing the date
    def day_bounds(date)
      date = date.to_date
      [date.to_time, (date + (1.days - 1.minute)).to_time]
    end
  end
end
