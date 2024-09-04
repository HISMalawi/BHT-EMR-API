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
      datetime = datetime&.to_time || datetime
      [datetime.strftime('%Y-%m-%d 00:00:00').to_time,
       datetime.strftime('%Y-%m-%d 23:59:59').to_time]
    end

    ##
    # Parses and validates start_date and end_date provided by users
    #
    # Returns: A pair of Date objects containing the start_date and end_date
    def parse_date_range(start_date, end_date)
      raise InvalidParameterError, 'start_date is required' if start_date.blank?
      raise InvalidParameterError, 'end_date is required' if end_date.blank?

      start_date = start_date.to_date
      end_date = end_date.to_date

      raise InvalidParameterError, "start_date can't be greater than end_date" if start_date > end_date

      [start_date, end_date]
    end

    # Returns a time object comprising the given date plus the current time.
    def retro_timestamp(date)
      return nil unless date

      date = date.to_time
      "#{date.strftime('%Y-%m-%d')} #{Time.now.strftime('%H:%M:%S')}".to_time
    end

    def get_person_age(birthdate:)
      ((Time.zone.now - birthdate.to_time) / 1.year.seconds).floor
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def smart_time_difference(start_time:, end_time:)
      time_diff = TimeDifference.between(DateTime.parse(start_time), DateTime.parse(end_time)).in_general

      if (time_diff[:years]).positive?
        "#{time_diff[:years]} year#{time_diff[:years] > 1 ? 's' : ''}"
      elsif (time_diff[:months]).positive?
        "#{time_diff[:months]} month#{time_diff[:months] > 1 ? 's' : ''}"
      elsif (time_diff[:weeks]).positive?
        "#{time_diff[:weeks]} week#{time_diff[:weeks] > 1 ? 's' : ''}"
      elsif (time_diff[:days]).positive?
        "#{time_diff[:days]} day#{time_diff[:days] > 1 ? 's' : ''}"
      elsif (time_diff[:hours]).positive?
        "#{time_diff[:hours]} hour#{time_diff[:hours] > 1 ? 's' : ''}"
      elsif (time_diff[:minutes]).positive?
        "#{time_diff[:minutes]} minute#{time_diff[:years] > 1 ? 's' : ''}"
      elsif (time_diff[:seconds]).positive?
        "#{time_diff[:seconds]} second#{time_diff[:years] > 1 ? 's' : ''}"
      else
        '0 seconds'
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
