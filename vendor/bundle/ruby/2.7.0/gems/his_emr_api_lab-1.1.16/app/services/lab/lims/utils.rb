# frozen_string_literal: true

require 'cgi/util'

module Lab
  module Lims
    ##
    # Various helper methods for modules in the Lims namespaces...
    module Utils
      LIMS_LOG_PATH = Rails.root.join('log', 'lims')
      FileUtils.mkdir_p(LIMS_LOG_PATH) unless File.exist?(LIMS_LOG_PATH)

      def logger
        Rails.logger
      end

      TEST_NAME_MAPPINGS = {
        # For some weird reason(s) some tests have multiple names in LIMS,
        # this is used to sanitize those names.
        'hiv_viral_load' => 'HIV Viral Load',
        'viral laod' => 'HIV Viral Load',
        'viral load' => 'HIV Viral Load',
        'i/ink' => 'India ink',
        'indian ink' => 'India ink'
      }.freeze

      def self.translate_test_name(test_name)
        TEST_NAME_MAPPINGS.fetch(test_name.downcase, test_name)
      end

      def self.structify(object)
        if object.is_a?(Hash)
          object.each_with_object(OpenStruct.new) do |kv_pair, struct|
            key, value = kv_pair

            struct[key] = structify(value)
          end
        elsif object.respond_to?(:map)
          object.map { |item| structify(item) }
        else
          object
        end
      end

      def self.lab_user
        user = User.find_by_username('lab_daemon')
        return user if user

        god_user = User.first

        person = Person.create!(creator: god_user.user_id)
        PersonName.create!(person: person, given_name: 'Lab', family_name: 'Daemon', creator: god_user.user_id)

        User.create!(username: 'lab_daemon', person: person, creator: god_user.user_id)
      end

      def self.parse_date(str_date, fallback_date = nil)
        str_date = str_date&.to_s

        if str_date.blank? && fallback_date.blank?
          raise "Can't parse blank date"
        end

        return parse_date(fallback_date) if str_date.blank?

        str_date = str_date.gsub(/^00/, '20').gsub(/^180/, '20')

        case str_date
        when /\d{4}-\d{2}-\d{2}/
          str_date
        when /\d{2}-\d{2}-\d{2}/
          Date.strptime(str_date, '%d-%m-%Y').strftime('%Y-%m-%d')
        when /(\d{4}\d{2}\d{2})\d+/
          Date.strptime(str_date, '%Y%m%d').strftime('%Y-%m-%d')
        when %r{\d{2}/\d{2}/\d{4}}
          str_date.to_date.to_s
        else
          Rails.logger.warn("Invalid date: #{str_date}")
          parse_date(fallback_date)
        end
      end

      def self.find_concept_by_name(name)
        ConceptName.joins(:concept)
                   .merge(Concept.all) # Filter out voided
                   .where(name: CGI.unescapeHTML(name))
                   .first
      end
    end
  end
end
