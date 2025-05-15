# frozen_string_literal: true

module ArtService
  class PatientStreamBuilder
    attr_reader :report, :patient_id, :date

    def initialize(patient_id:, date:)
      @report = {}
      @query_dir = File.join(Rails.root, 'db', 'sql', 'analytical_database')
      @patient_id = patient_id
      @date = date
    end

    QUERIES = %w[art_initial art_visit demographics outcomes].freeze

    # Builds the report data for a patient.
    #
    # This method fetches data for a patient, including demographics, appointments,
    # clinic visits, family planning, and lab orders. It returns a hash with the
    # patient's demographics and an array of visit data.
    def build
      QUERIES.each do |query|
        report[query] = send(query)
      end

      report
    end

    private

    def art_initial
      query = File.read(File.join(@query_dir, 'art_initial.sql'))
      raise "ART Initial (art_initial.sql) file not found at #{@query_dir}" unless query.present?

      query = query&.gsub('@patient_id', @patient_id.to_s)

      execute_query(query)
    end

    def art_visit
      query = File.read(File.join(@query_dir, 'art_visit.sql'))
      raise "ART Visit (art_visit.sql) file not found at #{@query_dir}" unless query.present?

      query = query&.gsub('@patient_id', @patient_id.to_s)
                   &.gsub('@visit_date', date.to_s)

      execute_query(query)
    end

    def demographics
      query = File.read(File.join(@query_dir, 'demographics.sql'))
      raise "Demographics (demographics.sql) file not found at #{@query_dir}" unless query.present?

      query = query&.gsub('@person_id', @patient_id.to_s)

      execute_query(query)
    end

    def outcomes
      query = File.read(File.join(@query_dir, 'outcomes.sql'))
      raise "Outcomes (outcomes.sql) file not found at #{@query_dir}" unless query.present?

      query = query&.gsub('@patient_id', @patient_id.to_s)
      execute_query(query)
    end

    def execute_query(query)
      ActiveRecord::Base.connection.select_one(query)
    end
  end
end
