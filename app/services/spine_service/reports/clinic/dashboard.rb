# frozen_string_literal: true

module SpineService
  module Reports
    module Clinic
      # This class implements dashboard report for Spine Clinic
      class Dashboard
        attr_reader :start_date, :end_date, :program

        def initialize(date:, **_kwargs)
          @start_date = date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @program = Program.find_by_name 'SPINE PROGRAM'
        end

        def fetch_report
          {
            rows: process_encounters,
            patient_summary_stats: process_graph_data
          }
        end

        private

        ENCOUNTERS = ['REGISTRATION', 'UPDATE HIV STATUS', 'INFLUENZA DATA', 'CHRONIC CONDITIONS', 'DIAGNOSIS',
                      'DISPENSING', 'TREATMENT', 'PATIENT OUTCOME'].freeze
        ENCOUNTER_MAP = {
          'REGISTRATION' => 'Patient registration',
          'UPDATE HIV STATUS' => 'HIV tests',
          'INFLUENZA DATA' => 'Influenza data',
          'CHRONIC CONDITIONS' => 'Chronic conditions',
          'DIAGNOSIS' => 'Patient diagnosis',
          'TREATMENT' => 'Prescription',
          'DISPENSING' => 'Dispensations',
          'PATIENT OUTCOME' => 'Discharges'
        }.freeze

        def process_graph_data
          stats = {}
          stats[:top] = {
            registered_today: registered_today(visit_type: 'New patient'),
            returning_today: registered_today(visit_type: 'Revisiting'),
            referred_today: registered_today(visit_type: 'Referral')
          }

          stats[:down] = {
            registered: monthly_registration(visit_type: 'New patient', date: start_date),
            returning: monthly_registration(visit_type: 'Revisiting', date: start_date),
            referred: monthly_registration(visit_type: 'Referral', date: start_date)
          }
          stats
        end

        def registered_today(visit_type:)
          type = EncounterType.find_by_name 'Patient registration'
          concept = ConceptName.find_by_name 'Type of visit'
          value_coded = ConceptName.find_by_name visit_type

          encounter_ids = Encounter.where('encounter_datetime BETWEEN ? AND ?
              AND encounter_type = ? AND program_id = ?', *TimeUtils.day_bounds(start_date.to_date), type.id, program.id).map(&:encounter_id)

          Observation.where('encounter_id IN(?) AND concept_id = ? AND value_coded = ?',
                            encounter_ids, concept.concept_id, value_coded.concept_id).group(:person_id).length
        end

        def monthly_registration(visit_type:, date:)
          start_date = (date.to_date - 12.month)
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
                AND value_coded = ? AND program_id = ?', date1.strftime('%Y-%m-%d 00:00:00'),
                                    date2.strftime('%Y-%m-%d 23:59:59'), type.id,
                                    concept.concept_id, value_coded.concept_id, program.id)\
                             .joins('INNER JOIN obs USING(encounter_id)')\
                             .select('COUNT(DISTINCT encounter_id) AS total')

            months[(i + 1)] = {
              start_date: date1, end_date: date2,
              count: count[0]['total'].to_i
            }
          end

          months
        end

        def process_encounters
          encounters = patient_providers_encounters
          encounters.each do |encounter|
            encounter['encounter'] = ENCOUNTER_MAP[encounter['encounter']]
          end
          encounters
        end

        # Get the patient providers encounter for the specified date
        #
        # @return [Array] An array of encounters
        def patient_providers_encounters
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              et.name encounter,
              COALESCE(female.total_encounters, 0) AS female,
              COALESCE(male.total_encounters, 0) AS male,
              COALESCE(individual_clinic.total_encounters, 0) AS me,
              COALESCE(clinic.total_encounters, 0) AS facility
            FROM encounter_type et
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              INNER JOIN person p ON p.person_id = e.patient_id AND LEFT(p.gender, 1) = 'F' AND p.voided = 0
              WHERE e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{program.id}
              GROUP BY e.encounter_type
            ) AS female ON female.encounter_type = et.encounter_type_id
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              INNER JOIN person p ON p.person_id = e.patient_id AND LEFT(p.gender, 1) = 'M' AND p.voided = 0
              WHERE e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{program.id}
              GROUP BY e.encounter_type
            ) AS male ON male.encounter_type = et.encounter_type_id
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{program.id}
              GROUP BY e.encounter_type
            ) AS clinic ON clinic.encounter_type = et.encounter_type_id
            LEFT JOIN (
              SELECT e.encounter_type, count(*) as total_encounters
              FROM encounter e
              WHERE e.encounter_datetime >= '#{@start_date}' AND e.encounter_datetime <= '#{@end_date}'
              AND e.voided = 0
              AND e.program_id = #{program.id}
              AND e.provider_id = #{User.current.id}
              GROUP BY e.encounter_type
            ) AS individual_clinic ON individual_clinic.encounter_type = et.encounter_type_id
            WHERE et.retired = 0
            AND et.name IN ('#{ENCOUNTERS.join("','")}')
          SQL
        end
      end
    end
  end
end
