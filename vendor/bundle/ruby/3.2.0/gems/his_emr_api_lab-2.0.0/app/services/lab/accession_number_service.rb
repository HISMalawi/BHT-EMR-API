# frozen_string_literal: true

module Lab
  # Responsible for the generation of tracking numbers
  module AccessionNumberService
    class << self
      # Returns the next accession number on the given date or today.
      #
      # Throws:
      #   RangeError - If date is greater than system date
      def next_accession_number(date = nil)
        date = validate_date(date || Date.today)
        counter = find_counter(date)

        counter.with_lock do
          accession_number = format_accession_number(date, counter.value)
          counter.value += 1
          counter.save!

          return accession_number
        end
      end

      private

      def find_counter(date)
        counter = Lab::LabAccessionNumberCounter.find_by(date:)
        return counter if counter

        Lab::LabAccessionNumberCounter.create(date:, value: 1)
      end

      # Checks if date does not exceed system date
      def validate_date(date)
        return date unless date > Date.today

        raise RangeError, "Specified date exceeds system date: #{date} > #{Date.today}"
      end

      def format_accession_number(date, counter)
        year = format_year(date.year)
        month = format_month(date.month)
        day = format_day(date.day)

        "X#{site_code}#{year}#{month}#{day}#{counter}"
      end

      def format_year(year)
        (year % 100).to_s.rjust(2, '0')
      end

      # It's base 32 that uses letters for values 10+ but the letters
      # are ordered in a way that seems rather arbitrary
      # (see #get_day in https://github.com/HISMalawi/nlims_controller/blob/3c0faf1cb6572a11cb3b9bd1ea8444f457d01fd7/lib/tracking_number_service.rb#L58)
      DAY_NUMBERING_SYSTEM = %w[1 2 3 4 5 6 7 8 9 A B C E F G H Y J K Z M N O P Q R S T V W X].freeze

      def format_day(day)
        DAY_NUMBERING_SYSTEM[day - 1]
      end

      def format_month(month)
        # Months use a base 13 numbering system that's just a subset of the
        # numbering system used for days
        format_day(month)
      end

      def site_code
        property = GlobalProperty.find_by(property: 'site_prefix')
        value = property&.property_value&.strip

        raise "Global property 'site_prefix' not set" unless value

        value
      end
    end
  end
end
