# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      # This is the Cohort Outcome class
      # rubocop:disable Metrics/ClassLength
      class Outcomes
        attr_reader :end_date, :definition, :rebuild

        def initialize(end_date:, definition: 'moh', **kwargs)
          definition = definition.downcase
          raise ArgumentError, "Invalid outcomes definition: #{definition}" unless %w[moh pepfar].include?(definition)

          @end_date = ActiveRecord::Base.connection.quote(end_date.to_date)
          @definition = definition
          @rebuild = kwargs[:rebuild]&.casecmp?('true')
        end

        def update_cummulative_outcomes
          prepare_tables
          clear_tables if rebuild
          update_steps unless rebuild
          process_data
        end

        def update_outcomes_by_definition
          prepare_tables
          update_steps(portion: true)
          load_patients_on_treatment
          load_without_clinical_contact
          load_defaulters
        end

        private

        # The main idea here is to come up with cumulative outcomes for patients in temp_earliest_start_date
        # 1. load_patients_who_died
        # 2. load_patients_who_stopped_treatment
        # 3. load_patients_without_drug_orders
        # 4. load_patients_on_treatment
        # 5. load_without_clinical_contact
        # 6. load_defaulters

        def program_states(*names)
          ::ProgramWorkflowState.joins(:program_workflow)
                                .joins(:concept)
                                .merge(::ProgramWorkflow.where(program: ::Program.find_by_name('HIV Program')))
                                .merge(::Concept.joins(:concept_names)
                                            .merge(::ConceptName.where(name: names)))
                                .select(:program_workflow_state_id)
        end

        # ===================================
        #  Data Management Region
        # ===================================
        def process_data
          denormalize
          # HIC SUNT DRACONIS: The order of the operations below matters,
          # do not change it unless you know what you are doing!!!
          load_patients_who_died
          load_patients_who_stopped_treatment
          load_patients_without_drug_orders
          load_patients_on_treatment
          load_without_clinical_contact
          load_defaulters
        end

        # rubocop:disable Metrics/MethodLength

        def denormalize
          load_max_drug_orders
          load_patient_current_medication
          update_patient_current_medication
          load_min_auto_expire_date
          load_max_patient_state
          load_patient_current_state
          update_patient_current_state
        end

        def load_max_drug_orders
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_drug_orders
            SELECT o.patient_id, MAX(o.start_date) AS start_date
            FROM orders o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.patient_id
            INNER JOIN drug_order ON drug_order.order_id = o.order_id AND drug_order.quantity > 0
              AND drug_order.drug_inventory_id IN (#{arv_drug})
            WHERE o.order_type_id = 1 -- drug order
              AND o.start_date < (DATE(#{end_date}) + INTERVAL 1 DAY)
              AND o.voided = 0
            GROUP BY o.patient_id
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date)
          SQL
        end

        def load_min_auto_expire_date
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_min_auto_expire_date
            SELECT cm.patient_id, MIN(cm.start_date), MIN(cm.expiry_date), MIN(cm.pepfar_defaulter_date), MIN(cm.moh_defaulter_date)
            FROM temp_current_medication cm
            GROUP BY cm.patient_id
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date), auto_expire_date = VALUES(auto_expire_date), pepfar_defaulter_date = VALUES(pepfar_defaulter_date), moh_defaulter_date = VALUES(moh_defaulter_date)
          SQL
        end

        def load_max_patient_state
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_patient_state
            SELECT pp.patient_id, MAX(ps.start_date) start_date
            FROM patient_state ps
            INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1 AND pp.voided = 0
            WHERE ps.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND ps.voided = 0 AND pp.patient_id IN (SELECT patient_id FROM temp_earliest_start_date)
            GROUP BY pp.patient_id
            HAVING start_date IS NOT NULL
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date)
          SQL
        end

        def load_patient_current_state
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_state
            SELECT mps.patient_id, cn.name AS cum_outcome, ps.start_date as outcome_date, ps.state, count(DISTINCT(ps.state)) outcomes, MAX(ps.patient_state_id) patient_state_id
            FROM patient_state ps
            INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1 AND pp.voided = 0
            INNER JOIN temp_max_patient_state mps ON mps.patient_id = pp.patient_id AND mps.start_date = ps.start_date
            INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state AND pws.retired = 0
            INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.voided = 0 AND cn.concept_name_type = 'FULLY_SPECIFIED'
            LEFT JOIN patient_state ps2 ON ps.patient_program_id = ps2.patient_program_id AND ps.start_date = ps2.start_date AND ps.date_created < ps2.date_created AND ps2.voided = 0
            WHERE ps2.patient_program_id IS NULL AND ps.voided = 0
            GROUP BY mps.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), state = VALUES(state), outcomes = VALUES(outcomes), patient_state_id = VALUES(patient_state_id)
          SQL
        end

        def update_patient_current_state
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_state
            SELECT cs.patient_id, cn.name as cum_outcome, ps.start_date as outcome_date, ps.state, 1, cs.patient_state_id
            FROM patient_state ps
            INNER JOIN temp_current_state cs ON cs.patient_state_id = ps.patient_state_id
            INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state AND pws.retired = 0
            INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' AND cn.voided = 0
            WHERE ps.voided = 0 AND cs.outcomes > 1
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), state = VALUES(state), outcomes = VALUES(outcomes), patient_state_id = VALUES(patient_state_id)
          SQL
        end

        def load_patient_current_medication
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_medication
            SELECT mdo.patient_id, d.concept_id, do.drug_inventory_id drug_id,
              CASE
                WHEN do.equivalent_daily_dose IS NULL THEN 1
                WHEN do.equivalent_daily_dose = 0 THEN 1
                WHEN do.equivalent_daily_dose REGEXP '^[0-9]+(\.[0-9]+)?$' THEN do.equivalent_daily_dose
                ELSE 1
              END daily_dose,
              SUM(do.quantity) quantity,
              DATE(mdo.start_date) start_date, null, null, null, null
            FROM temp_max_drug_orders mdo
            INNER JOIN orders o ON o.patient_id = mdo.patient_id AND o.order_type_id = 1 AND DATE(o.start_date) = DATE(mdo.start_date) AND o.voided = 0
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0 AND do.drug_inventory_id IN (#{arv_drug})
            INNER JOIN drug d ON d.drug_id = do.drug_inventory_id
            GROUP BY mdo.patient_id, do.drug_inventory_id HAVING quantity < 6000
            ON DUPLICATE KEY UPDATE concept_id = VALUES(concept_id), daily_dose = VALUES(daily_dose), quantity=VALUES(quantity), start_date = VALUES(start_date), pill_count = VALUES(pill_count), expiry_date = VALUES(expiry_date), pepfar_defaulter_date = VALUES(pepfar_defaulter_date), moh_defaulter_date = VALUES(moh_defaulter_date);
          SQL
        end

        def update_patient_current_medication
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_medication
            SELECT cm.patient_id, cm.concept_id, cm.drug_id, cm.daily_dose, cm.quantity, cm.start_date,
            COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0) AS pill_count,
            DATE_ADD(DATE_SUB(cm.start_date, INTERVAL 1 DAY), INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY),
            DATE_ADD(DATE_ADD(DATE_SUB(cm.start_date, INTERVAL 1 DAY), INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY), INTERVAL 30 DAY),
            DATE_ADD(DATE_ADD(DATE_SUB(cm.start_date, INTERVAL 1 DAY), INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY), INTERVAL 60 DAY)
            FROM temp_current_medication cm
            LEFT JOIN (
            SELECT ob.person_id, cm.drug_id,
            SUM(ob.value_numeric) + SUM(CASE
              WHEN ob.value_text is null then 0
              WHEN ob.value_text REGEXP '^[0-9]+(\.[0-9]+)?$' then ob.value_text
              ELSE 0
            END) quantity
            FROM obs ob
            INNER JOIN temp_current_medication cm ON cm.patient_id = ob.person_id AND cm.start_date = DATE(ob.obs_datetime)
            INNER JOIN orders o ON o.order_id = ob.order_id AND o.voided = 0
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.drug_inventory_id = cm.drug_id
            WHERE ob.concept_id = 2540 AND ob.voided = 0
            GROUP BY ob.person_id, cm.drug_id
            ) first_ob ON first_ob.person_id = cm.patient_id AND first_ob.drug_id = cm.drug_id
            LEFT JOIN obs second_ob ON second_ob.person_id = cm.patient_id AND second_ob.concept_id = cm.concept_id AND DATE(second_ob.obs_datetime) = cm.start_date AND second_ob.voided = 0
            LEFT JOIN obs third_ob ON third_ob.person_id = cm.patient_id AND third_ob.concept_id = 2540 AND third_ob.value_drug = cm.drug_id AND third_ob.voided = 0 AND DATE(third_ob.obs_datetime) = cm.start_date
            GROUP BY cm.patient_id, cm.drug_id
            ON DUPLICATE KEY UPDATE pill_count = VALUES(pill_count), expiry_date = VALUES(expiry_date), pepfar_defaulter_date = VALUES(pepfar_defaulter_date), moh_defaulter_date = VALUES(moh_defaulter_date);
          SQL
        end

        # Loads all patiens with an outcome of died as of given date
        # into the temp_patient_outcomes table.
        def load_patients_who_died
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id, 'Patient died', patient_state.start_date, 1
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = (#{program_states('Patient died').limit(1).to_sql})
              AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND patient_state.voided = 0
            WHERE patients.date_enrolled <= DATE(#{end_date})
            AND patient_state.date_created = (
              SELECT MAX(date_created)
              FROM patient_state ps
              WHERE ps.patient_program_id = patient_state.patient_program_id
              AND ps.state = patient_state.state AND ps.voided = 0 AND ps.start_date <= #{end_date})
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Loads all patients with an outcome of transferred out or
        # treatment stopped into temp_patient_outcomes table.
        def load_patients_who_stopped_treatment
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id,
              patients.cum_outcome,
              patients.outcome_date, 2
            FROM temp_current_state AS patients
            WHERE (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step = 1)
            AND patients.outcomes = 1
            AND patients.state IN (
              SELECT pws.program_workflow_state_id state
              FROM program_workflow pw
              INNER JOIN program_workflow_state pws ON pws.program_workflow_id = pw.program_workflow_id AND pws.retired = 0
              WHERE pw.program_id = 1 AND pw.retired = 0 AND pws.terminal = 1
              AND pws.program_workflow_state_id IN (2, 3, 6) -- Transferred out,Patient Died, Treatment stopped
            )
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load all patients without drug orders or have drug orders
        # without a quantity.
        def load_patients_without_drug_orders
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id,
                   'Unknown',
                   NULL, 3
            FROM temp_earliest_start_date AS patients
            WHERE date_enrolled <= #{end_date}
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2))
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_max_drug_orders)
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Loads all patients who are on treatment
        def load_patients_on_treatment
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id, 'On antiretrovirals', COALESCE(cs.outcome_date, patients.start_date), 4
            FROM temp_min_auto_expire_date AS patients
            LEFT JOIN temp_current_state AS cs ON cs.patient_id = patients.patient_id
            WHERE patients.#{@definition == 'pepfar' ? 'pepfar_defaulter_date' : 'moh_defaulter_date'} > #{end_date}
            AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        def load_without_clinical_contact
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id, 'Defaulted', null, 5
            FROM temp_current_medication AS patients
            LEFT JOIN temp_current_state AS cs ON cs.patient_id = patients.patient_id
            WHERE patients.#{@definition == 'pepfar' ? 'pepfar_defaulter_date' : 'moh_defaulter_date'} <= #{end_date}
            AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load defaulters
        def load_defaulters
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patient_id, #{patient_outcome_function('patient_id')}, NULL, 6
            FROM temp_earliest_start_date
            WHERE date_enrolled <= #{end_date}
            AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4, 5))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # rubocop:enable Metrics/MethodLength

        # ===================================
        #  Function Management Region
        # ===================================
        def patient_outcome_function(sql_column)
          case @definition
          when 'moh' then "patient_outcome(#{sql_column}, #{end_date})"
          when 'pepfar' then "pepfar_patient_outcome(#{sql_column}, #{end_date})"
          else raise "Invalid outcomes definition: #{@definition}"
          end
        end

        # ===================================
        #  Table Management Region
        # ===================================
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Metrics/CyclomaticComplexity
        def prepare_tables
          create_outcome_table unless check_if_table_exists('temp_patient_outcomes')
          drop_temp_patient_outcome_table unless count_table_columns('temp_patient_outcomes') == 4
          create_temp_max_drug_orders_table unless check_if_table_exists('temp_max_drug_orders')
          create_tmp_min_auto_expire_date unless check_if_table_exists('temp_min_auto_expire_date')
          drop_tmp_min_auto_expirte_date unless count_table_columns('temp_min_auto_expire_date') == 5
          create_temp_max_patient_state unless check_if_table_exists('temp_max_patient_state')
          create_temp_current_state unless check_if_table_exists('temp_current_state')
          create_temp_current_medication unless check_if_table_exists('temp_current_medication')
          drop_temp_current_state unless count_table_columns('temp_current_state') == 6
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/CyclomaticComplexity

        def create_temp_current_medication
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_current_medication(
              patient_id INT NOT NULL,
              concept_id INT NOT NULL,
              drug_id INT NOT NULL,
              daily_dose DECIMAL(32,2) NOT NULL,
              quantity DECIMAL(32,2) NOT NULL,
              start_date DATE NOT NULL,
              pill_count DECIMAL(32,2) NULL,
              expiry_date DATE NULL,
              pepfar_defaulter_date DATE NULL,
              moh_defaulter_date DATE NULL,
              PRIMARY KEY(patient_id, drug_id)
            )
          SQL
          craete_tmp_current_med_index
        end

        def craete_tmp_current_med_index
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_cm_concept ON temp_current_medication (concept_id)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_cm_drug ON temp_current_medication (drug_id)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_cm_date ON temp_current_medication (start_date)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_cm_pepfar ON temp_current_medication (pepfar_defaulter_date)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_cm_moh ON temp_current_medication (moh_defaulter_date)
          SQL
        end

        def create_temp_current_state
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_current_state(
              patient_id INT NOT NULL,
              cum_outcome VARCHAR(120) NOT NULL,
              outcome_date DATE DEFAULT NULL,
              state INT NOT NULL,
              outcomes INT NOT NULL,
              patient_state_id INT NOT NULL,
              PRIMARY KEY(patient_id))
          SQL
          create_current_state_index
        end

        def create_current_state_index
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_state_name ON temp_current_state (cum_outcome)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_state_id ON temp_current_state (state)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_state_count ON temp_current_state (outcomes)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_patient_state_id ON temp_current_state (patient_state_id)
          SQL
        end

        def create_tmp_min_auto_expire_date
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_min_auto_expire_date (
              patient_id INT NOT NULL,
              start_date DATE DEFAULT NULL,
              auto_expire_date DATE DEFAULT NULL,
              pepfar_defaulter_date DATE DEFAULT NULL,
              moh_defaulter_date DATE DEFAULT NULL,
              PRIMARY KEY (patient_id)
            )
          SQL
          create_min_auto_expire_date_indexes
        end
        # rubocop:enable Metrics/MethodLength

        def drop_temp_current_state
          ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_current_state')
          create_temp_current_state
        end

        def check_if_table_exists(table_name)
          result = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT COUNT(*) AS count
            FROM information_schema.tables
            WHERE table_schema = DATABASE()
            AND table_name = '#{table_name}'
          SQL
          result['count'].to_i.positive?
        end

        def count_table_columns(table_name)
          result = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT COUNT(*) AS count
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE table_schema = DATABASE()
            AND table_name = '#{table_name}'
          SQL
          result['count'].to_i
        end

        def drop_temp_patient_outcome_table
          ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_patient_outcomes')
          create_outcome_table
        end

        def create_outcome_table
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_patient_outcomes (
            patient_id INT NOT NULL,
            cum_outcome VARCHAR(120) NOT NULL,
            outcome_date DATE DEFAULT NULL,
            step INT DEFAULT 0,
            PRIMARY KEY (patient_id)
            )
          SQL
          create_outcome_indexes
        end

        def create_outcome_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_outcome ON temp_patient_outcomes (cum_outcome)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_out_date ON temp_patient_outcomes (outcome_date)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_out_step ON temp_patient_outcomes (step)
          SQL
        end

        def create_temp_max_drug_orders_table
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_max_drug_orders (
              patient_id INT NOT NULL,
              start_date DATETIME DEFAULT NULL,
              PRIMARY KEY (patient_id)
            )
          SQL
          create_max_drug_orders_indexes
        end

        def create_max_drug_orders_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_max_orders ON temp_max_drug_orders (start_date)
          SQL
        end

        def drop_tmp_min_auto_expirte_date
          ActiveRecord::Base.connection.execute 'DROP TABLE temp_min_auto_expire_date'
          create_tmp_min_auto_expire_date
        end

        def create_min_auto_expire_date_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_min_auto_expire_date ON temp_min_auto_expire_date (auto_expire_date)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_min_pepfar ON temp_min_auto_expire_date (pepfar_defaulter_date)
          SQL
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_min_moh ON temp_min_auto_expire_date (moh_defaulter_date)
          SQL
        end

        def create_temp_max_patient_state
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_max_patient_state (
              patient_id INT NOT NULL,
              start_date VARCHAR(15) DEFAULT NULL,
              PRIMARY KEY (patient_id)
            )
          SQL
          create_max_patient_state_indexes
        end

        def create_max_patient_state_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_max_patient_state ON temp_max_patient_state (start_date)
          SQL
        end

        def update_steps(portion: false)
          ActiveRecord::Base.connection.execute <<~SQL
            UPDATE temp_patient_outcomes SET step = 0 WHERE step >= #{portion ? 4 : 0}
          SQL
        end

        def arv_drug
          @arv_drug ||= ::Drug.arv_drugs.map(&:drug_id).join(',')
        end

        def clear_tables
          ActiveRecord::Base.connection.execute('TRUNCATE temp_patient_outcomes')
          ActiveRecord::Base.connection.execute('TRUNCATE temp_max_drug_orders')
          ActiveRecord::Base.connection.execute('TRUNCATE temp_min_auto_expire_date')
          ActiveRecord::Base.connection.execute('TRUNCATE temp_max_patient_state')
          ActiveRecord::Base.connection.execute('TRUNCATE temp_current_state')
          ActiveRecord::Base.connection.execute('TRUNCATE temp_current_medication')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
