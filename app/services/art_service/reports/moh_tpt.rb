# frozen_string_literal: true

module ARTService
  module Reports
    # This class generates the MOH TPT report
    class MohTpt
      attr_reader :start_date, :end_date, :start_of_month, :end_of_month, :raw_end_date, :raw_start_date

      def initialize(start_date:, end_date:, **_kwarg)
        @raw_end_date = end_date.to_date
        @raw_start_date = start_date.to_date
        @start_date = start_date - 9.months
        @end_date = @start_date + 3.months
        @start_of_month = @start_date.beginning_of_month
        @end_of_month = @end_date.end_of_month
      end

      def data
        report = init_report
        drop_tables
        initiated_on_art
        initiated_on_tpt
        create_indexes
        process_initiated_on_art report, fetch_initiated_on_art
        process_initiated_tpt report, fetch_initiated_on_tpt
        response = []
        report.each do |key, value|
          response << { age_group: key, gender: 'F', **value['F'] }
          response << { age_group: key, gender: 'M', **value['M'] }
        end
        response
      end

      private

      GENDERS = %w[F M].freeze
      AGE_GROUPS = ['<1 year', '1-4 years', '5-9 years', '10-14 years', '15-19 years',
                    '20-24 years', '25-29 years', '30-34 years', '35-39 years', '40-44 years',
                    '45-49 years', '50-54 years', '55-59 years', '60-64 years', '65-69 years',
                    '70-74 years', '75-79 years', '80-84 years', '85-89 years',
                    '90 plus years'].freeze

      def init_report
        AGE_GROUPS.each_with_object({}) do |age_group, report|
          report[age_group] = GENDERS.each_with_object({}) do |gender, tpt_report|
            tpt_report[gender] = {
              initiated_art: [], started_tpt: [], not_completed_tpt: [],
              completed_tpt: [], died: [], pregnant: [],
              defaulted: [], stopped: [],
              transfer_out: [], confirmed_tb: [],
              breast_feeding: [], skin_rash: [],
              nausea: [], peripheral_neuropathy: [],
              dizziness: [], yellow_eyes: []
            }
          end
        end
      end

      def process_initiated_on_art(report, patients)
        patients.each do |patient|
          report[patient['age_group']][patient['gender']][:initiated_art] << patient['patient_id']
        end
      end

      def process_initiated_tpt(report, patients)
        ARTService::Reports::TptOutcome.new(start_date: start_date, end_date: raw_end_date)
                                       .moh_report(report, patients, start_date, end_date)
      end

      def fetch_initiated_on_art
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_id, age_group, gender FROM temp_initiated_on_art
          WHERE art_start_date >= DATE('#{start_of_month}')
        SQL
      end

      def fetch_initiated_on_tpt
        result = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT * FROM temp_initiated_on_tpt
          WHERE start_date >= DATE('#{start_of_month}')
        SQL
        # convert to array of hashes
        result.to_a
      end

      def initiated_on_art
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_initiated_on_art
          SELECT pp.patient_id, coalesce(o.value_datetime, min(art_order.start_date)) art_start_date, p.gender, disaggregated_age_group(p.birthdate, DATE('#{raw_end_date}')) age_group
          FROM patient_program pp
          INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
          INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- ON ART
          INNER JOIN orders art_order ON art_order.patient_id = pp.patient_id
            AND art_order.start_date >= DATE('#{start_of_month}')
            AND art_order.start_date < DATE('#{end_of_month}') + INTERVAL 1 DAY
            AND art_order.voided = 0
            AND art_order.order_type_id = 1 -- Drug order
            AND art_order.concept_id IN (#{arv_concepts})
          INNER JOIN drug_order do ON do.order_id = art_order.order_id AND do.quantity > 0
          LEFT JOIN encounter e ON e.patient_id = pp.patient_id
            AND e.encounter_type = 9 -- HIV CLINIC REGISTRATION
            AND e.voided = 0
            AND e.encounter_datetime < DATE('#{end_of_month}') + INTERVAL 1 DAY
            AND e.program_id = 1 -- HIV program
          LEFT JOIN obs o ON o.person_id = pp.patient_id
            AND o.concept_id = 2516 -- ART start date
            AND o.encounter_id = e.encounter_id
            AND o.voided = 0
          WHERE pp.patient_id NOT IN (
            SELECT o.patient_id
            FROM orders o
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0
            WHERE o.order_type_id = 1 -- Drug order
              AND o.voided  = 0
              AND o.concept_id IN (#{arv_concepts})
              AND o.start_date < DATE('#{start_of_month}')
            GROUP BY o.patient_id
          )
          AND pp.program_id = 1 -- HIV program
          GROUP BY pp.patient_id
        SQL
      end

      def initiated_on_tpt
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_initiated_on_tpt
          SELECT
            pp.patient_id,
            coalesce(tpt_transfer_in_obs.value_datetime, min(tpt_order.start_date)) start_date,
            p.gender, disaggregated_age_group(p.birthdate, DATE('#{raw_end_date}')) age_group,
            patient_outcome(p.person_id, DATE('#{@raw_end_date}')) AS outcome,
            GROUP_CONCAT(DISTINCT tpt_order.concept_id SEPARATOR ',') AS drug_concepts,
            CASE
              WHEN count(DISTINCT tpt_order.concept_id) >  1 THEN '3HP'
              WHEN tpt_order.concept_id = 10565 THEN '3HP'
              ELSE '6H'
            END AS tpt_type
          FROM patient_program pp
          INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
          INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- ON ART
          INNER JOIN orders tpt_order ON tpt_order.patient_id = pp.patient_id
            AND tpt_order.start_date >= DATE('#{start_of_month}')
            AND tpt_order.start_date < DATE('#{end_of_month}') + INTERVAL 1 DAY
            AND tpt_order.voided = 0
            AND tpt_order.order_type_id = 1 -- Drug order
            AND tpt_order.concept_id IN (#{tpt_concepts})
          INNER JOIN drug_order do ON do.order_id = tpt_order.order_id AND do.quantity > 0
          LEFT JOIN obs tpt_transfer_in_obs ON tpt_transfer_in_obs.person_id = pp.patient_id
            AND tpt_transfer_in_obs.concept_id = #{ConceptName.find_by_name('TPT Drugs Received').concept_id}
            AND tpt_transfer_in_obs.voided = 0
            AND tpt_transfer_in_obs.value_drug IN (#{tpt_concepts})
            AND tpt_transfer_in_obs.obs_datetime < DATE('#{end_of_month}') + INTERVAL 1 DAY
          WHERE pp.patient_id NOT IN (
            SELECT o.patient_id
            FROM orders o
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0
            WHERE o.order_type_id = 1 -- Drug order
              AND o.voided  = 0
              AND o.concept_id IN (#{tpt_concepts})
              AND o.start_date < DATE('#{start_of_month}')
            GROUP BY o.patient_id
          )
          AND pp.program_id = 1 -- HIV program
          GROUP BY pp.patient_id
        SQL
      end

      def drop_tables
        execute_query 'DROP TABLE IF EXISTS temp_initiated_on_art'
        execute_query 'DROP TABLE IF EXISTS temp_initiated_on_tpt'
      end

      def create_indexes
        execute_query 'CREATE INDEX idx_temp_initiated_on_art ON temp_initiated_on_art(patient_id)'
        execute_query 'CREATE INDEX idx_temp_initiated_on_tpt ON temp_initiated_on_tpt(patient_id)'
      end

      def execute_query(query)
        ActiveRecord::Base.connection.execute(query)
      end

      def arv_concepts
        @arv_concepts ||= ConceptSet.where(concept_set: ConceptName.where(name: 'Antiretroviral drugs')
                                                                   .select(:concept_id))
                                    .collect(&:concept_id).join(',')
      end

      def tpt_concepts
        @tpt_concepts ||= ConceptName.where(name: ['Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine'])
                                     .collect(&:concept_id).join(',')
      end
    end
  end
end
