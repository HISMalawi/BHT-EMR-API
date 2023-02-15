# frozen_string_literal: true

module ARTService
  module Reports
    # this report is used to generate regimen data
    class RegimenData
      attr_reader :start_date, :end_date, :type

      def initialize(start_date:, end_date:, type:)
        @start_date = ActiveRecord::Base.connection.quote(start_date)
        @end_date = ActiveRecord::Base.connection.quote(end_date)
        @type = type
      end

      def data
        drop_regimen_data
        clients_alive_on_treatment
        process_clients
      end

      private

      def create_filtered_data
        create_temp_current_dispensation
        create_temp_drug_dispensed
        create_temp_current_regimen
        create_temp_current_patient_regimen
        create_temp_patient_outcome
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
          SELECT o.patient_id, od.drug_inventory_id, d.name, o.start_date
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
        ActiveRecord::Base.connection.execute 'create index regimen_names on temp_current_regimen_names (drugs)'
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

      def clients_alive_on_treatment
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE table tmp_latest_arv_dispensation
          SELECT
            o.patient_id,
            o.start_date,
            pe.gender,
            pe.birthdate,
            pn.given_name,
            pn.family_name,
            i.identifier arv_number,
            o.order_id,
            GROUP_CONCAT(CONCAT('{"medication":"', d.name, '", "start_date": "', DATE(o.start_date),'", "quantity":"',od.quantity,'"}')) medication,
            cast(patient_date_enrolled(o.patient_id) as date) AS date_enrolled,
            date_antiretrovirals_started(o.patient_id, min(ps.start_date)) AS earliest_start_date, #{current_outcome} outcome, #{current_regimen} regimen
          FROM orders o
          INNER JOIN drug_order od ON od.order_id = o.order_id AND od.quantity > 0 AND od.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
          INNER JOIN drug d ON d.drug_id = od.drug_inventory_id AND d.retired = 0
          INNER JOIN (
            SELECT o.patient_id, MAX(o.start_date) AS start_date
            FROM orders o
            INNER JOIN drug_order od ON od.order_id = o.order_id AND od.quantity > 0 AND od.drug_inventory_id IN (SELECT drug_id FROM arv_drug)
            WHERE o.start_date > #{end_date} - INTERVAL 18 MONTH AND o.start_date < #{end_date} + INTERVAL 1 DAY
            AND o.voided = 0
            AND o.order_type_id = 1
            GROUP BY o.patient_id
          ) AS last_order ON last_order.patient_id = o.patient_id AND last_order.start_date = o.start_date
          INNER JOIN patient p ON p.patient_id = o.patient_id AND p.voided = 0
          INNER JOIN person pe ON pe.person_id = o.patient_id AND pe.voided = 0
          INNER JOIN patient_program pg ON pg.patient_id = o.patient_id AND pg.program_id = 1 AND pg.voided = 0
          LEFT JOIN patient_state ps ON ps.patient_program_id = pg.patient_program_id AND ps.voided = 0 AND ps.state = 7 AND ps.start_date <= #{end_date} + INTERVAL 1 DAY
          LEFT JOIN person_name pn ON pn.person_id = pe.person_id AND pn.voided = 0
          LEFT JOIN patient_identifier i ON i.patient_id = pe.person_id AND i.identifier_type = 4 AND i.voided = 0
          WHERE o.voided = 0
          GROUP BY o.patient_id
        SQL
      end

      def current_outcome
        outcome = ", patient_outcome(o.patient_id, #{end_date}) outcome"
        outcome = ", pepfar_patient_outcome(o.patient_id, #{end_date}) outcome" if type == 'pepfar'
        outcome
      end

      def current_regimen
        ", patient_current_regimen(o.patient_id, #{end_date}) regimen"
      end

      def drop_regimen_data
        ActiveRecord::Base.connection.execute('drop table if exists tmp_latest_arv_dispensation ;')
      end

      def alive_clients(fields)
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT #{fields || '*'} FROM tmp_latest_arv_dispensation where outcome = 'On antiretrovirals'
        SQL
      end

      def process_clients
        clients = {}
        @vl_result = vl_result
        @maternal_status = maternal_status
        alive_clients(nil).each do |client|
          clients[client['patient_id']] = {
            arv_number: client['arv_number'],
            given_name: client['given_name'],
            family_name: client['family_name'],
            birthdate: client['birthdate'],
            gender: client['gender'] == 'M' ? 'M' : maternal_status(patient_id, demo['gender']),
            current_regimen: client['regimen'],
            current_weight: current_weight(patient_id),
            art_start_date: client['earliest_start_date'],
            medication: [],
            vl_result: fetch_viral_load(client['patient_id']) ? @result['result'] : nil,
            vl_result_date: @result ? @result['result_date'] : nil
          }
        end
      end

      def vl_result
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT lab_result_obs.obs_datetime AS result_date,
          CONCAT (COALESCE(measure.value_modifier, '='),' ',COALESCE(measure.value_numeric, measure.value_text, '')) as result,
          obs.person_id AS patient_id
          FROM obs AS lab_result_obs
          INNER JOIN orders
            ON orders.order_id = lab_result_obs.order_id
            AND orders.voided = 0
          INNER JOIN obs AS measure
            ON measure.obs_group_id = lab_result_obs.obs_id
            AND measure.voided = 0
          INNER JOIN (
            SELECT concept_id, name
            FROM concept_name
            INNER JOIN concept USING (concept_id)
            WHERE concept.retired = 0
            AND name NOT LIKE 'Lab test result'
            GROUP BY concept_id
          ) AS measure_concept
            ON measure_concept.concept_id = measure.concept_id
          WHERE lab_result_obs.voided = 0
          AND measure.person_id IN (SELECT patient_id FROM tmp_latest_arv_dispensation WHERE outcome = 'On antiretrovirals')
          AND (measure.value_numeric IS NOT NULL || measure.value_text IS NOT NULL)
          AND lab_result_obs.obs_datetime <= '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          ORDER BY lab_result_obs.obs_datetime DESC
        SQL
      end

      def maternal_status
        ARTService::Reports::Pepfar::ViralLoadCoverage2.new(start_date: @start_date,
                                                            end_date: @end_date).vl_maternal_status(alive_clients('patient_id').map do |client|
                                                                                                      client['patient_id']
                                                                                                    end.uniq.join(',') || 0)
      end

      def fetch_viral_load(patient_id)
        return nil if patient_id.blank?

        # return the row where the patient_id is equal to the patient_id in the @viral_load array
        @result = @viral_load.select { |row| row['patient_id'] == patient_id }.first
        return nil if @result.blank?

        @result
      end

      def fetch_maternal_status(patient_id)
        return nil if patient_id.blank?

        gender = 'FNP'
        gender = 'FP' if @maternal_status[:FP].include?(patient_id)
        gender = 'FBf' if @maternal_status[:FBf].include?(patient_id)
        gender
      end

      def current_weight(patient_id)
        weight_concept = ConceptName.find_by_name('Weight (kg)').concept_id
        obs = Observation.where("person_id = ? AND concept_id = ?
          AND obs_datetime <= ? AND (value_numeric IS NOT NULL OR value_text IS NOT NULL)",
                                patient_id, weight_concept, @end_date.to_date.strftime('%Y-%m-%d 23:59:59'))\
                         .order('obs_datetime DESC, date_created DESC')

        return nil if obs.blank?

        (obs.first.value_numeric.blank? ? obs.first.value_text : obs.first.value_numeric)
      end
    end
  end
end
