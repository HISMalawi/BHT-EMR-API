# frozen_string_literal: true

module ARTService
  module Reports
    module Clinic
      # Generates a hypertension report for a clinic
      # rubocop:disable Metrics/ClassLength
      class HypertensionReport
        AGE_GROUPS = [
          '20-24 years',
          '25-29 years', '30-34 years',
          '35-39 years', '40-44 years',
          '45-49 years', '50-54 years',
          '55-59 years', '60-64 years',
          '65-69 years', '70-74 years',
          '75-79 years', '80-84 years',
          '85-89 years',
          '90 plus years'
        ].freeze

        GENDER = %w[M F].freeze

        DRUG_MAPPING = {
          'Hydrochlorothiazide (25mg tablet)' => :hydrochlorothiazide_25mg,
          'HCZ (25mg tablet)' => :hydrochlorothiazide_25mg,
          'Hctz (25mg)' => :hydrochlorothiazide_25mg,
          'Amlodipine (5mg tablet)' => :amlodipine_5mg,
          'Amlodipine 5mg' => :amlodipine_5mg,
          'Amlodipine (5mg)' => :amlodipine_5mg,
          'Amlodipine (10mg tablet)' => :amlodipine_10mg,
          'Enalapril (5mg tablet)' => :enalapril_5mg,
          'Enalapril (5mg)' => :enalapril_5mg,
          'Enalapril (10mg tablet)' => :enalapril_10mg,
          'Enalapril (10mg)' => :enalapril_10mg,
          'Atenolol (50mg tablet)' => :atenolol_50mg,
          'Atenolol (50mg)' => :atenolol_50mg,
          'Atenolol (100mg tablet)' => :atenolol_100mg
        }.freeze

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          @report = init_report
          process_data
          @report
        rescue StandardError => e
          puts e.message
          puts e.backtrace.join("\n")
          raise e
        end

        private

        def init_report
          AGE_GROUPS.each_with_object({}) do |age_group, report|
            report[age_group] = GENDER.each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = initialize_gender_metrics
            end
          end
        end

        # rubocop:disable Metrics/MethodLength
        def initialize_gender_metrics
          {
            screened: [],
            normal_reading: [],
            mild_reading: [],
            moderate_reading: [],
            severe_reading: [],
            hydrochlorothiazide_25mg: [],
            amlodipine_5mg: [],
            amlodipine_10mg: [],
            enalapril_5mg: [],
            enalapril_10mg: [],
            atenolol_50mg: [],
            atenolol_100mg: [],
            total_regimen: []
          }
        end
        # rubocop:enable Metrics/MethodLength

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def process_data
          (data || []).each do |row|
            age_group = row['age_group']
            gender = row['gender']
            next unless AGE_GROUPS.include?(age_group)
            next unless GENDER.include?(gender)

            patient = client_info(row)
            cluster = @report[age_group][gender]
            cluster[:screened] << patient
            process_bp_classification(cluster, patient, row['systolic_classification'], row['diastolic_classification'])
            process_drug_data(cluster, patient, row['drug_names'].split(',')) if row['drug_names'].present?
            cluster[:total_regimen] << patient if row['drug_names'].present?
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        def process_bp_classification(cluster, patient_id, sys_class, dia_class)
          classification = SEVERITY_ORDER[sys_class.to_sym] > SEVERITY_ORDER[dia_class.to_sym] ? sys_class : dia_class
          case SEVERITY_CLASSIFICATION[classification.to_sym]
          when 'NORMAL'
            cluster[:normal_reading] << patient_id
          when 'MILD'
            cluster[:mild_reading] << patient_id
          when 'MODERATE'
            cluster[:moderate_reading] << patient_id
          when 'SEVERE'
            cluster[:severe_reading] << patient_id
          end
        end

        def process_drug_data(cluster, patient_id, drugs)
          return if drugs.blank?

          drugs.each do |drug|
            cluster_key = DRUG_MAPPING[drug]
            cluster[cluster_key] << patient_id if cluster_key
          end
        end

        SEVERITY_ORDER = {
          severe_reading: 4,
          moderate_reading: 3,
          mild_reading: 2,
          normal_reading: 1   
        }.freeze

        SEVERITY_CLASSIFICATION = {
          severe_reading: 'SEVERE',
          moderate_reading: 'MODERATE',
          mild_reading: 'MILD',
          normal_reading: 'NORMAL'
        }.freeze

        def data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                tpo.patient_id,
                sys.value_numeric systolic,
                dia.value_numeric diastolic,
                CASE
                    WHEN sys.value_numeric <= 139 THEN 'normal_reading'
                    WHEN sys.value_numeric > 139 AND sys.value_numeric <= 159 THEN 'mild_reading'
                    WHEN sys.value_numeric > 159 AND sys.value_numeric <= 179 THEN 'moderate_reading'
                    WHEN sys.value_numeric > 179 THEN 'severe_reading'
                END AS systolic_classification,
                CASE
                    WHEN dia.value_numeric <= 89 THEN 'normal_reading'
                    WHEN dia.value_numeric > 89 AND dia.value_numeric <= 99 THEN 'mild_reading'
                    WHEN dia.value_numeric > 99 AND dia.value_numeric <= 109 THEN 'moderate_reading'
                    WHEN dia.value_numeric > 109 THEN 'severe_reading'
                END AS diastolic_classification,
                UPPER(LEFT(p.gender, 1)) gender,
                disaggregated_age_group(p.birthdate, #{@end_date}) age_group,
                i.identifier arv_number,
                latest_drug_order.start_date,
                GROUP_CONCAT(DISTINCT d.name) drug_names
            FROM (
                SELECT MAX(o.obs_datetime) obs_date, o.person_id patient_id
                FROM obs o
                INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1 -- HIV PROGRAM
                WHERE o.concept_id = 5085 -- Systolic blood pressure
                AND o.voided = 0 AND o.obs_datetime >= #{@start_date} AND o.obs_datetime < #{@end_date} + INTERVAL 1 DAY
                GROUP BY o.person_id
            ) AS tpo
            INNER JOIN obs sys ON sys.concept_id = 5085 AND sys.person_id = tpo.patient_id AND sys.obs_datetime = tpo.obs_date AND sys.voided = 0
            INNER JOIN obs dia ON dia.concept_id = 5086 AND dia.person_id = tpo.patient_id AND dia.obs_datetime = tpo.obs_date AND dia.voided = 0
            INNER JOIN person p ON p.person_id = tpo.patient_id AND p.voided = 0
            INNER JOIN encounter e ON e.encounter_id = dia.encounter_id AND e.program_id = 1 AND e.voided = 0
            LEFT JOIN patient_identifier i ON i.patient_id = e.patient_id AND i.identifier_type = 4 AND i.voided = 0
            LEFT JOIN (
                SELECT o.patient_id, MAX(o.start_date) start_date
                FROM orders o
                INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
                WHERE o.voided = 0
                    AND o.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE '%Hydrochlorothiazide%' OR name LIKE '%Amlodipine%' OR name LIKE '%Enalapril%' OR name LIKE '%Atenolol%')
                    AND o.start_date >= #{@start_date} AND o.start_date < #{@end_date} + INTERVAL 1 DAY
                GROUP BY o.patient_id
            ) AS latest_drug_order ON latest_drug_order.patient_id = tpo.patient_id AND DATE(latest_drug_order.start_date) >= DATE(tpo.obs_date)
            LEFT JOIN orders ord ON ord.start_date = latest_drug_order.start_date AND ord.patient_id = latest_drug_order.patient_id AND ord.voided = 0 AND ord.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE '%Hydrochlorothiazide%' OR name LIKE '%Amlodipine%' OR name LIKE '%Enalapril%' OR name LIKE '%Atenolol%')
            LEFT JOIN drug_order dor ON dor.order_id = ord.order_id AND dor.quantity > 0
            LEFT JOIN drug d ON d.drug_id = dor.drug_inventory_id AND d.retired = 0
            WHERE tpo.patient_id NOT IN (#{external_clients})
            GROUP BY tpo.patient_id
            ORDER BY tpo.patient_id ASC
          SQL
        end

        def external_clients
          <<~SQL
            SELECT obs.person_id FROM obs,
            (SELECT person_id, Max(obs_datetime) AS obs_datetime, concept_id FROM obs
            WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
            AND DATE(obs_datetime) <= #{@end_date}
            AND voided = 0
            GROUP BY person_id) latest_record
            WHERE obs.person_id = latest_record.person_id
            AND obs.concept_id = latest_record.concept_id
            AND obs.obs_datetime = latest_record.obs_datetime
            AND obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'Drug refill' || name = 'External consultation')
            AND obs.voided = 0
          SQL
        end

        def client_info(data)
          {
            patient_id: data['patient_id'],
            arv_number: data['arv_number'],
            gender: data['gender'],
            diastolic: data['diastolic'],
            systolic: data['systolic']
          }
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
