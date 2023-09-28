# frozen_string_literal: true

module AetcService
  # A hash of encounter types and their display names
  class DashboardStats
    ENCOUNTERS = {
      social_history: 'SOCIAL HISTORY',
      outpatient_reception: 'PATIENT REGISTRATION',
      vitals: 'VITALS',
      presenting_complaints: 'PRESENTING COMPLAINTS',
      outpatient_diagnosis: 'OUTPATIENT DIAGNOSIS',
      prescription: 'PRESCRIPTION',
      dispensing: 'DISPENSING',
      treatment: 'TREATMENT'
    }.freeze

    # An array of report groups
    REPORT_GROUP = %i[me facility].freeze

    # Initializes a new instance of the DashboardStats class
    #
    # @param date [Date] The date to generate the report for
    def initialize(date)
      @program = Program.find_by_name 'AETC PROGRAM'
      @date = date || Date.today
    end

    # Generates a report of dashboard stats
    #
    # @return [Hash] A hash of dashboard stats
    def find_report
      build_report
      tranform_report
    end

    private

    # Initializes the report structure
    #
    # @return [Hash] A hash representing the report structure
    def initialize_report_structure
      ENCOUNTERS.transform_values do |_value|
        REPORT_GROUP.each_with_object({}) do |group, sub_report|
          sub_report[group] = {}
        end
      end
    end

    # Builds the report
    #
    # @return [void]
    def build_report
      @report = initialize_report_structure
      ENCOUNTERS.each do |encounter, name|
        REPORT_GROUP.each do |group|
          result = count_encounters name, group
          @report[encounter][group] = result
          @report[encounter][:total] = 0 unless @report[encounter][:total]
          @report[encounter][:total] += result
        end
      end
    end

    # Transforms the report
    #
    # @return [void]
    def tranform_report
      @report.map do |encounter, sub_report|
        {
          name: ENCOUNTERS[encounter],
          me: sub_report[:me],
          facility: sub_report[:facility],
          total: sub_report[:total]
        }
      end
    end

    # Counts the number of encounters of a given type and group on a given date
    #
    # @param encounter [String] The name of the encounter type to count
    # @param group [Symbol] The group to count encounters for (:me or :facility)
    # @return [Integer] The number of encounters of the given type and group on the given date
    def count_encounters(encounter, group)
      filter = { encounter_type: EncounterType.find_by_name(encounter) }
      filter[:program] = @program
      filter[:provider] = User.current.person if group == :me
      filter[:encounter_datetime] = @date.beginning_of_day..@date.end_of_day
      Encounter.where(filter).count
    end
  end
end
