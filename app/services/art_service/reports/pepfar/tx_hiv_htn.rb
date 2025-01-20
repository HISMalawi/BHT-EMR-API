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
          @report = (pepfar_age_groups - ['Unknown']).each_with_object({}) do |age_group, report|
            report[age_group] = %w[M F].each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = indicators
            end
          end
          process_aggreggation_rows
        end

        # [
          #   {
            #     "patient_id": 1256,
            #     "systolic": 160.0,
        #     "diastolic": 100.0,
        #     "date_screened_for_htn": "2024-12-05",
        #     "diagnosed": 1,
        #     "date_diagnosed": "2024-12-04",
        #   },
        # ]
        def map_results(patients:)

          patients.each do |p|
            next if p['age_group'] == 'Unknown'

            id = p['patient_id']
            diagonised = p["diagonised"]
            date_diagnosed = p["date_diagnosed"]
            systolic = p["systolic"]
            diastolic = p["diastolic"]
            maternal_status = p["maternal_status"]
            gender = p["gender"]
            age_group = p["age_group"]

            @report[age_group][gender][:tx_curr] << id
            @report["All"][maternal_status][:tx_curr] << id

            @report[age_group][gender][:screened_for_htn] << id
            @report["All"][maternal_status][:screened_for_htn] << id

            if diagonised == 1
              @report[age_group][gender][:ever_diagnosed_htn] << id 
              @report['All'][maternal_status][:ever_diagnosed_htn] << id
            end
            if diagonised == 1 && date_diagnosed > start_date
              @report[age_group][gender][:newly_diagnosed_htn] << id 
              @report["All"][maternal_status][:newly_diagnosed_htn] << id
            end

            next unless systolic && diastolic

            if systolic < SYSTOLIC_THRESHOLD && diastolic < DIASTOLIC_THRESHOLD
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
              disaggregated_age_group(tesd.birthdate, DATE('#{end_date.to_date}')) age_group,
              LEFT(tesd.gender, 1) AS gender,
              systolic.value_numeric AS systolic,
              diastolic.value_numeric AS diastolic,
              DATE(vitals.encounter_datetime) AS date_screened_for_htn,
              IF (diagnosed.patient_id IS NOT NULL, 1, 0) AS diagonised,
              DATE(diagnosed.date_diagonised) AS date_diagnosed,
              IF (ms.maternal_status IS NOT NULL, 
                ms.maternal_status, 
                IF (tesd.gender = 'M', 'Male', 'FNP')) AS maternal_status
            FROM temp_earliest_start_date tesd
            INNER JOIN temp_patient_outcomes tpo
              ON tpo.patient_id = tesd.patient_id
              AND tpo.pepfar_cum_outcome = 'On antiretrovirals'
            LEFT JOIN encounter vitals
              ON vitals.patient_id = tesd.patient_id
              AND vitals.voided = 0
              AND vitals.encounter_type = #{encounter_type("VITALS").id}
              AND DATE(vitals.encounter_datetime) BETWEEN DATE('#{start_date - 6.months}') AND DATE('#{end_date}')
            LEFT JOIN obs systolic
              ON systolic.encounter_id = vitals.encounter_id
              AND systolic.voided = 0
              AND systolic.concept_id = #{concept("Systolic blood pressure").id}
            LEFT JOIN obs diastolic
              ON diastolic.encounter_id = vitals.encounter_id
              AND diastolic.voided = 0
              AND diastolic.concept_id = #{concept("Diastolic blood pressure").id}
            LEFT JOIN (
              SELECT p.patient_id, date_diagnosied.value_datetime AS date_diagonised
              FROM patient p
              INNER JOIN encounter e ON e.patient_id = p.patient_id
              AND e.voided = 0
              AND e.encounter_type = #{encounter_type("HIV CLINIC CONSULTATION").id}
              AND DATE(e.encounter_datetime) BETWEEN DATE('#{start_date - 6.months}') AND DATE('#{end_date}')
              INNER JOIN obs date_diagnosied ON date_diagnosied.encounter_id = e.encounter_id
              AND date_diagnosied.voided = 0
              AND date_diagnosied.concept_id = #{concept("Hypertension diagnosis date").id}
            ) diagnosed ON diagnosed.patient_id = tesd.patient_id
            LEFT JOIN temp_maternal_status ms ON ms.patient_id = tesd.patient_id
            GROUP BY tesd.patient_id
          SQL
        end
      end
    end
  end
end
