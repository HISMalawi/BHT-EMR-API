# frozen_string_literal: true

require 'set'

module VmmcService
  class ReportEngine
    attr_reader :program
    include ModelUtils

    LOGGER = Rails.logger

    REPORTS = {
      'COHORT' => VmmcService::Reports::Cohort
    }.freeze

    # def initialize(program:, date:)
    #   @program = program
    #   @date = date
    # end

    def dashboard_stats(date)
      @date = date

      stats = {}

      generic_encounters = %w[registration vitals medical_history update_hiv_status genital_examination circumcision]

      (generic_encounters || []).each do |encounter|
        stats[encounter] = map_stats(encounter, true)
      end

      stats
    end

    def find_report(type:, name:, start_date:, end_date:)
      report = REPORTS[type.upcase]
      raise InvalidParameterError, "Report type (#{type}) not known" unless report

      indicator = report.new(start_date, end_date).method(name.strip.to_sym)
      raise InvalidParameterError, "Report indicator (#{name}) not known" unless indicator

      { name => indicator.call }
    end

    private

    # stats_mapping
    def map_stats(stats_type, generic = false)
      if generic == true
        encounter_name = stats_type.titlecase
        stats_by_user = generic_encounter_statistics(encounter_name, 'by_user')
        stats_today = generic_encounter_statistics(encounter_name, 'today')
        stats_this_year = generic_encounter_statistics(encounter_name, 'this_year')
        stats_total_to_date = generic_encounter_statistics(encounter_name, 'total')

      end

      {
        stats_by_user: stats_by_user,
        stats_today: stats_today,
        stats_this_year: stats_this_year,
        stats_total_to_date: stats_total_to_date
      }
    end

    def generic_encounter_statistics(encounter_name, stats_type)
      type = EncounterType.find_by_name encounter_name
      raise encounter_name.inspect unless type

      case stats_type
      when 'by_user'
        creator = User.current.user_id

        count = Encounter.where('program_id = 21 AND encounter_type = ? AND encounter.creator = ?', type.id, creator)\
                         .select('count(*) AS total')
      when 'today'
        count = Encounter.where('program_id = 21 AND encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ? ', *TimeUtils.day_bounds(@date), type.id)\
                         .select('count(*) AS total')
      when 'this_year'

        start_date = Date.today.beginning_of_year
        end_date = Date.today.end_of_year

        count = Encounter.where('program_id = 21 AND encounter_datetime BETWEEN ? AND ?
      AND encounter_type = ? ', start_date, end_date, type.id)\
                         .select('count(*) AS total')
      when 'total'

        count = Encounter.where('program_id = 21 AND encounter_type = ? ', type.id)\
                         .select('count(*) AS total')
      end

      count[0]['total'].to_i
    end

    # observations
    def observations(stats_type)
      case stats_type
      when 'by_user'
        count = Observation.joins(:encounter).where('program_id = 21').select('count(*) AS total')

      when 'today'
        count = Observation.where('program_id = 21 AND obs_datetime BETWEEN ? AND ?', *TimeUtils.day_bounds(@date))\
                           .joins(:encounter)
        select('count(*) AS total')
      when 'this_year'

        start_date = Date.today.beginning_of_year
        end_date = Date.today.end_of_year

        count = Observation.where('program_id = 21 AND obs_datetime BETWEEN ? AND ? ', start_date, end_date)\
                           .joins(:encounter)
        select('count(*) AS total')
      when 'total'

        count = Observation.joins(:encounter).where('program_id = 21').select('count(*) AS total')

      end

      count[0]['total'].to_i
    end
  end
end
