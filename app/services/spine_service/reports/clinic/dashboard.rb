# frozen_string_literal: true

module SpineService
  module Reports
    module Clinic
      # This class implements dashboard report for Spine Clinic
      class Dashboard
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def fetch_report
          # TODO: Implement this method
        end

        private

        VISIT_TYPES = ['New patient', 'Revisiting', 'Referral'].freeze
        ENCOUNTERS = ['Patient Registration', 'LAB RESULTS', 'INFLUENZA DATA', 'CHRONIC CONDITIONS', 'Patient Diagnosis', 'PRESCRIPTION', 'DISCHARGE PATIENT'].freeze

        def registered_today(visit_type:)
          type = EncounterType.find_by_name 'Patient registration'
          concept = ConceptName.find_by_name 'Type of visit'
          value_coded = ConceptName.find_by_name visit_type

          encounter_ids = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ?', *TimeUtils.day_bounds(@date), type.id).map(&:encounter_id)

          Observation.where('encounter_id IN(?) AND concept_id = ? AND value_coded = ?',
                            encounter_ids, concept.concept_id, value_coded.concept_id).group(:person_id).length
        end

        def monthly_registration(visit_type:)
          start_date = (@date - 12.month)
          dates = []

          start_date = start_date.beginning_of_month
          end_date = start_date.end_of_month
          dates << [start_date, end_date]

          1.upto(12) do |m|
            sdate = start_date + m.month
            edate = sdate.end_of_month
            dates << [sdate, edate]
          end

          type = EncounterType.find_by_name 'Patient registration'
          concept = ConceptName.find_by_name 'Type of visit'
          value_coded = ConceptName.find_by_name visit_type

          months = {}

          (dates || []).each_with_index do |(date1, date2), i|
            count = Encounter.where('encounter_datetime BETWEEN ? AND ?
                AND encounter_type = ? AND concept_id = ?
                AND value_coded = ?', date1.strftime('%Y-%m-%d 00:00:00'),
                                    date2.strftime('%Y-%m-%d 23:59:59'), type.id,
                                    concept.concept_id, value_coded.concept_id)\
                             .joins('INNER JOIN obs USING(encounter_id)')\
                             .select('COUNT(DISTINCT encounter_id) AS total')

            months[(i + 1)] = {
              start_date: date1, end_date: date2,
              count: count[0]['total'].to_i
            }
          end

          months
        end
      end
    end
  end
end
