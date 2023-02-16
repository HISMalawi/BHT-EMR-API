# frozen_string_literal: true

module ARTService
  module Reports
    # this report is used to generate regimen data
    class RegimenData
      attr_reader :start_date, :end_date, :type

      def initialize(start_date:, end_date:, **kwargs)
        @start_date = ActiveRecord::Base.connection.quote(start_date)
        @end_date = ActiveRecord::Base.connection.quote(end_date)
        @type = kwargs[:type]
      end

      def find_report
        drop_regimen_data
        create_filtered_data
        process_clients
      end

      private

      def drop_regimen_data
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_current_dispensation'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_drug_dispensed'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_current_regimen_names'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_current_patient_regimen'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_reg_outcome'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_vl_results'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_current_vl_results'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_regimen_patient_weight'
        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_regimen_data'
      end

      def create_filtered_data
        create_temp_current_dispensation
        create_temp_drug_dispensed
        create_temp_current_regimen
        create_temp_current_patient_regimen
        create_temp_patient_outcome
        create_temp_vl_result
        create_temp_current_vl_results
        create_temp_regimen_patient_weight
      end

      def create_temp_current_dispensation
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_current_dispensation
          SELECT o.patient_id, MAX(o.start_date) AS start_date
          FROM orders o
          INNER JOIN drug_order od ON od.order_id = o.order_id AND od.quantity > 0 AND od.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
          WHERE o.start_date > #{end_date} - INTERVAL 18 MONTH AND o.start_date < #{end_date} + INTERVAL 1 DAY
          AND o.voided = 0
          AND o.order_type_id = 1 -- drug order
          GROUP BY o.patient_id
        SQL
        ActiveRecord::Base.connection.execute 'create index current_disp on temp_current_dispensation (patient_id, start_date)'
      end

      def create_temp_drug_dispensed
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE table temp_drug_dispensed
          SELECT o.patient_id, od.drug_inventory_id, d.name, o.start_date, od.quantity
          FROM orders o
          INNER JOIN temp_current_dispensation tcd ON tcd.patient_id = o.patient_id AND tcd.start_date = o.start_date
          INNER JOIN drug_order od ON od.order_id = o.order_id AND od.quantity > 0 AND od.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id AND d.retired  = 0
          WHERE o.voided = 0
          AND o.order_type_id = 1 -- drug order
        SQL
        ActiveRecord::Base.connection.execute 'create index drug_disp on temp_drug_dispensed (patient_id, start_date)'
      end

      def create_temp_current_regimen
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE table temp_current_regimen_names
          SELECT GROUP_CONCAT(drug.drug_id ORDER BY drug.drug_id ASC) AS drugs, regimen_name.name AS name
          FROM moh_regimen_combination AS combo
          INNER JOIN moh_regimen_combination_drug AS drug USING (regimen_combination_id)
          INNER JOIN moh_regimen_name AS regimen_name USING (regimen_name_id)
          GROUP BY combo.regimen_combination_id
        SQL
        ActiveRecord::Base.connection.execute 'create index regimen_names on temp_current_regimen_names (drugs(50))'
      end

      def create_temp_current_patient_regimen
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE table temp_current_patient_regimen
          SELECT patient_id, name
          FROM temp_current_regimen_names tcrn
          INNER JOIN (
            SELECT patient_id, GROUP_CONCAT(drug_inventory_id ORDER BY drug_inventory_id ASC) AS drugs
              FROM temp_drug_dispensed
              GROUP BY patient_id
          ) d ON d.drugs = tcrn.drugs
        SQL
        ActiveRecord::Base.connection.execute 'create index patient_regimen on temp_current_patient_regimen (patient_id)'
      end

      def create_temp_patient_outcome
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_reg_outcome
          SELECT patient_id, patient_outcome(patient_id, #{end_date}) outcome
          FROM temp_current_dispensation
        SQL
        ActiveRecord::Base.connection.execute 'create index reg_outcome on temp_reg_outcome (patient_id)'
      end

      def create_temp_vl_result
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE table temp_vl_results
          SELECT
            lab_result_obs.obs_datetime AS result_date,
            CONCAT (COALESCE(measure.value_modifier, '='),' ',COALESCE(measure.value_numeric, measure.value_text, '')) AS result,
            lab_result_obs.person_id AS patient_id
          FROM obs AS lab_result_obs
          INNER JOIN orders ON orders.order_id = lab_result_obs.order_id AND orders.voided = 0
          INNER JOIN obs AS measure ON measure.obs_group_id = lab_result_obs.obs_id AND measure.voided = 0
          INNER JOIN (
            SELECT concept_id, name
            FROM concept_name
            INNER JOIN concept USING (concept_id)
            WHERE concept.retired = 0
            AND name NOT LIKE 'Lab test result'
            GROUP BY concept_id
          ) AS measure_concept ON measure_concept.concept_id = measure.concept_id
          WHERE lab_result_obs.voided = 0
          AND measure.person_id IN (SELECT patient_id FROM temp_reg_outcome WHERE outcome = 'On antiretrovirals')
          AND (measure.value_numeric IS NOT NULL || measure.value_text IS NOT NULL)
          AND lab_result_obs.obs_datetime < #{end_date} + INTERVAL 1 DAY
          ORDER BY lab_result_obs.obs_datetime DESC
        SQL
        ActiveRecord::Base.connection.execute 'create index vl_result on temp_vl_results (patient_id, result_date)'
      end

      def create_temp_current_vl_results
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_current_vl_results
          SELECT t.*
          FROM temp_vl_results t
          LEFT JOIN temp_vl_results td ON td.patient_id = t.patient_id AND td.result_date > t.result_date
          WHERE td.patient_id IS NULL
        SQL
        ActiveRecord::Base.connection.execute 'create index current_vl on temp_current_vl_results (patient_id)'
      end

      def create_temp_regimen_patient_weight
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_regimen_patient_weight
          SELECT tro.patient_id, o.value_numeric AS weight
          FROM temp_reg_outcome tro
          INNER JOIN (
            SELECT person_id, MAX(obs_datetime) AS max_datetime
            FROM obs
            WHERE concept_id = 5089 AND voided = 0 AND obs_datetime < #{end_date} + INTERVAL 1 DAY
            GROUP BY person_id
          ) latest_obs ON latest_obs.person_id = tro.patient_id
          INNER JOIN obs o ON o.person_id = latest_obs.person_id AND o.concept_id = 5089 AND o.obs_datetime = latest_obs.max_datetime AND o.voided = 0 AND o.obs_datetime < #{end_date} + INTERVAL 1 DAY
          WHERE tro.outcome = 'On antiretrovirals'
        SQL
        ActiveRecord::Base.connection.execute 'create index patient_weight on temp_regimen_patient_weight (patient_id)'
      end

      def clients_alive_on_treatment
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            trc.patient_id,
            p.gender,
            p.birthdate,
            pn.given_name,
            pn.family_name,
            i.identifier arv_number,
            tpw.weight,
            tcvr.result_date,
            tcvr.result,
            GROUP_CONCAT(CONCAT('{medication:"', tdd.name, '", start_date: "', DATE(tdd.start_date),'", quantity:"',tdd.quantity,'"}')) medication
          FROM temp_reg_outcome trc
          INNER JOIN temp_current_patient_regimen tcp ON tcp.patient_id = trc.patient_id
          INNER JOIN temp_drug_dispensed tdd ON tdd.patient_id = trc.patient_id
          INNER JOIN person p ON p.person_id = trc.patient_id AND p.voided = 0
          INNER JOIN person_name pn ON pn.person_id = p.person_id AND pn.voided = 0
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id AND i.identifier_type = 4 AND i.voided = 0
          LEFT JOIN temp_regimen_patient_weight tpw ON tpw.patient_id = trc.patient_id
          LEFT JOIN temp_current_vl_results tcvr ON tcvr.patient_id = trc.patient_id
          WHERE trc.outcome = 'On antiretrovirals'
          GROUP BY trc.patient_id
        SQL
      end

      def alive_clients
        clients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT trc.patient_id
          FROM temp_reg_outcome trc
          INNER JOIN person p ON p.person_id = trc.patient_id AND p.voided = 0
          where trc.outcome = 'On antiretrovirals' AND LEFT(p.gender, 1) = 'F'
        SQL
        clients.map { |client| client['patient_id'] }
      end

      def process_clients
        clients = {}
        @maternal_status = maternal_status
        clients_alive_on_treatment.each do |client|
          clients[client['patient_id']] = {
            arv_number: client['arv_number'],
            given_name: client['given_name'],
            family_name: client['family_name'],
            birthdate: client['birthdate'],
            gender: client['gender'] == 'M' ? 'M' : fetch_maternal_status(client['patient_id']),
            current_regimen: client['regimen'],
            current_weight: client['weight'],
            art_start_date: client['earliest_start_date'],
            medication: client['medication'].split(',').map(&:as_json) || [],
            vl_result: client['result'],
            vl_result_date: client['result_date']
          }
        end
        clients
      end

      def maternal_status
        ARTService::Reports::Pepfar::ViralLoadCoverage2.new(start_date: @start_date,
                                                            end_date: @end_date).vl_maternal_status(alive_clients)
      end

      def fetch_maternal_status(patient_id)
        return nil if patient_id.blank?

        gender = 'FNP'
        gender = 'FP' if @maternal_status[:FP].include?(patient_id)
        gender = 'FBf' if @maternal_status[:FBf].include?(patient_id)
        gender
      end
    end
  end
end
