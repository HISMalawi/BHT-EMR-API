# frozen_string_literal: true

# This module wraps all radiology methods
module RadiologyService
  # this module handles the logic for coming up with the next accession number
  module AccessionNumberService
    class << self
      def next_accession_number(date = nil)
        date = validate_date(date || Date.today)
        counter = find_current_counter(date)

        counter.with_lock do
          accession_number = format_accession_number(date, counter.value)
          counter.value += 1
          counter.save
          return accession_number
        end
      end

      private

      def find_current_counter(date)
        counter = RadiologyAccessionNumberCounter.find_by(date: date)
        return counter if counter

        RadiologyAccessionNumberCounter.create(date: date, value: 1)
      end

      def validate_date(date)
        return date unless date > Date.today

        raise ArgumentError, "Date must be in the past: #{date} > #{Date.today}"
      end

      # Will use the numbering system like the one used in lab orders
      DAY_NUMBERING_SYSTEM = %w[1 2 3 4 5 6 7 8 9 A B C E F G H Y J K Z M N O P Q R S T V W X].freeze

      def format_accession_number(date, counter)
        year = format_year(date.year)
        # month is a subset of the DAY_NUMBERING_SYSTEM seeing it only has 12 elements
        month = format_day(date.month)
        day = format_day(date.day)

        "R#{GlobalPropertyService.site_code}#{year}#{month}#{day}#{counter}"
      end

      def format_day(day)
        DAY_NUMBERING_SYSTEM[day - 1]
      end

      def format_year(year)
        (year % 100).to_s.rjust(2, '0')
      end
    end
  end
end
