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
    def day_bounds(datetime)
      datetime = datetime&.to_datetime || datetime
      [datetime.strftime('%Y-%m-%d 00:00:00').to_datetime,
       datetime.strftime('%Y-%m-%d 23:59:59').to_datetime]
    end

    # Returns a time object comprising the given date plus the current time.
    def retro_timestamp(date)
      date = date.to_time
      "#{date.strftime('%Y-%m-%d')} #{Time.now.strftime('%H:%M')}".to_time
    end
  end
end
