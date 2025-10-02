# frozen_string_literal: true

module ArtService
  module Reports
    module Pepfar
      class TxHivHtn < CachedReport
        include ModelUtils
        include Pepfar::Utils
        include CommonSqlQueryUtils

        attr_reader :start_date, :end_date, :rebuild, :occupation

        SYSTOLIC_THRESHOLD = 140
        DIASTOLIC_THRESHOLD = 90

        def initialize(start_date:, end_date:, **kwargs)
          super(start_date:, end_date:, **kwargs)
          ArtService::Reports::MaternalStatus.new(start_date:, end_date:, **kwargs).process_data
        end

        def find_report
          init_report
          patients = screened_for_htn
          map_results(patients:)
          @report
        end

        def build_report
          find_report
        end

        def children_age_groups
          ['Unknown', '<1 year', '1-4 years', '5-9 years', '10-14 years']
        end

        def indicators
          {
                tx_curr: [],
                ever_diagnosed_htn: [],
                screened_for_htn: [],
                newly_diagnosed_htn: [],
                controlled_htn: [],
              }
        end

        def init_report
          @report = (pepfar_age_groups - children_age_groups).each_with_object({}) do |age_group, report|
            report[age_group] = %w[M F].each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = indicators
            end
          end
          process_aggreggation_rows
        end
        def map_results(patients:)

          patients.each do |p|
            next if p['age_group'] == 'Unknown' || children_age_groups.include?(p['age_group'])

            id = p['patient_id']
            diagonised = p["diagonised"]
            date_diagnosed = p["date_diagnosed"]
            systolic = p["systolic"]
            diastolic = p["diastolic"]
            had_previous_high_bp = p["had_previous_high_bp"]
            maternal_status = p["maternal_status"]
            gender = p["gender"]
            age_group = p["age_group"]

            @report[age_group][gender][:tx_curr] << id
            @report["All"][maternal_status][:tx_curr] << id

            if systolic && diastolic
              @report[age_group][gender][:screened_for_htn] << id
              @report["All"][maternal_status][:screened_for_htn] << id
            end

            if diagonised == 1
              @report[age_group][gender][:ever_diagnosed_htn] << id
              @report['All'][maternal_status][:ever_diagnosed_htn] << id
            end

            if diagonised == 1 && date_diagnosed && date_diagnosed > start_date
              @report[age_group][gender][:newly_diagnosed_htn] << id
              @report["All"][maternal_status][:newly_diagnosed_htn] << id
            end

            next unless systolic && diastolic

            if (diagonised == 1) && (systolic < SYSTOLIC_THRESHOLD && diastolic < DIASTOLIC_THRESHOLD) && (had_previous_high_bp == 1)
              @report[age_group][gender][:controlled_htn] << id
              @report["All"][maternal_status][:controlled_htn] << id
            end
          end

        end

        def process_aggreggation_rows     
          @report["All"] = {}
          @report['All']['Male'] = indicators
          
          %w[Male FP FNP FBf].each do |key|
            @report['All'][key] = indicators
          end
        end

        def screened_for_htn
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tesd.patient_id,
              disaggregated_age_group(tesd.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) age_group,
              LEFT(tesd.gender, 1) AS gender,
              vitals.systolic,
              vitals.diastolic,
              vitals.date_screened_for_htn,
              IF (diagnosed.patient_id IS NOT NULL, 1, 0) AS diagonised,
              DATE(diagnosed.date_diagonised) AS date_diagnosed,
              IF (previous_high_bp.patient_id IS NOT NULL, 1, 0) AS had_previous_high_bp,
              IF (ms.maternal_status IS NOT NULL,
                ms.maternal_status,
                IF (tesd.gender = 'M', 'Male', 'FNP')) AS maternal_status
            FROM temp_earliest_start_date tesd
            INNER JOIN temp_patient_outcomes tpo
              ON tpo.patient_id = tesd.patient_id
              AND tpo.pepfar_cum_outcome = 'On antiretrovirals'
            LEFT JOIN (
              SELECT
                vitals.patient_id,
                MAX(vitals.encounter_datetime) AS date_screened_for_htn,
                CAST(SUBSTRING_INDEX(GROUP_CONCAT(systolic.value_numeric ORDER BY vitals.encounter_datetime DESC), ',', 1) AS DECIMAL(10,2)) AS systolic,
                CAST(SUBSTRING_INDEX(GROUP_CONCAT(diastolic.value_numeric ORDER BY vitals.encounter_datetime DESC), ',', 1) AS DECIMAL(10,2)) AS diastolic
              FROM encounter vitals
              INNER JOIN obs systolic
                ON systolic.encounter_id = vitals.encounter_id
                AND systolic.voided = 0
                AND systolic.concept_id = #{concept("Systolic blood pressure").id}
              INNER JOIN obs diastolic
                ON diastolic.encounter_id = vitals.encounter_id
                AND diastolic.voided = 0
                AND diastolic.concept_id = #{concept("Diastolic blood pressure").id}
              WHERE vitals.voided = 0
                AND vitals.encounter_type = #{encounter_type("VITALS").id}
                AND DATE(vitals.encounter_datetime) >= #{ActiveRecord::Base.connection.quote(start_date)}
                AND DATE(vitals.encounter_datetime) <= #{ActiveRecord::Base.connection.quote(end_date)}
              GROUP BY vitals.patient_id
            ) vitals ON vitals.patient_id = tesd.patient_id
            LEFT JOIN (
              SELECT p.patient_id, date_diagnosied.value_datetime AS date_diagonised
              FROM patient p
              INNER JOIN encounter e ON e.patient_id = p.patient_id
                AND e.voided = 0
                AND e.encounter_type = #{encounter_type("HIV CLINIC CONSULTATION").id}
                AND DATE(e.encounter_datetime) <= #{ActiveRecord::Base.connection.quote(end_date)}
              INNER JOIN obs date_diagnosied ON date_diagnosied.encounter_id = e.encounter_id
                AND date_diagnosied.voided = 0
                AND date_diagnosied.concept_id = #{concept("Hypertension diagnosis date").id}
            ) diagnosed ON diagnosed.patient_id = tesd.patient_id
            LEFT JOIN (
              SELECT DISTINCT e.patient_id
              FROM encounter e
              INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0
              WHERE e.voided = 0
                AND e.encounter_type = #{encounter_type("VITALS").id}
                AND DATE(e.encounter_datetime) <= #{ActiveRecord::Base.connection.quote(end_date)}
                AND ((o.concept_id = #{concept("Systolic blood pressure").id}
                AND o.value_numeric >= #{SYSTOLIC_THRESHOLD})
                OR (o.concept_id = #{concept("Diastolic blood pressure").id}
                AND o.value_numeric >= #{DIASTOLIC_THRESHOLD}))
            ) previous_high_bp ON previous_high_bp.patient_id = tesd.patient_id
            LEFT JOIN temp_maternal_status ms ON ms.patient_id = tesd.patient_id
            GROUP BY tesd.patient_id
          SQL
        end
      end
    end
  end
end
