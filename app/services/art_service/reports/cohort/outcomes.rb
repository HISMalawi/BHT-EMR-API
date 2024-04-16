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

        private

        # The main idea here is to come up with cumulative outcomes for patients in temp_earliest_start_date
        # 1. load_patients_who_died
        # 2. load_patients_who_stopped_treatment
        # 3. load_patients_on_pre_art
        # 4. load_patients_without_state
        # 5. load_patients_without_drug_orders
        # 6. load_patients_on_treatment
        # 7. load_without_clinical_contact
        # 8. load_defaulters

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
          load_max_drug_orders
          load_min_auto_expire_date
          load_max_patient_state
          load_max_appointment_date
          # HIC SUNT DRACONIS: The order of the operations below matters,
          # do not change it unless you know what you are doing!!!
          load_patients_who_died
          load_patients_who_stopped_treatment
          load_patients_on_pre_art
          load_patients_without_state
          load_patients_without_drug_orders
          load_patients_on_treatment
          load_without_clinical_contact
          load_defaulters
        end

        # rubocop:disable Metrics/MethodLength

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
            SELECT patient_id, MIN(auto_expire_date) AS auto_expire_date
            FROM orders o
            INNER JOIN temp_max_drug_orders USING (patient_id, start_date)
            INNER JOIN drug_order ON drug_order.order_id = o.order_id AND drug_order.quantity > 0
              AND drug_order.drug_inventory_id IN (#{arv_drug})
            WHERE o.order_type_id = 1 AND o.voided = 0
            GROUP BY patient_id
            HAVING auto_expire_date IS NOT NULL
            ON DUPLICATE KEY UPDATE auto_expire_date = VALUES(auto_expire_date)
          SQL
        end

        def load_max_appointment_date
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_patient_appointment
            SELECT o.person_id, DATE(MAX(o.value_datetime)) appointment_date
            FROM obs o
            INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0
              AND e.program_id = 1 AND e.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
            WHERE o.concept_id = 5096 AND o.voided = 0 AND o.obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
            GROUP BY o.person_id
            HAVING appointment_date IS NOT NULL
            ON DUPLICATE KEY UPDATE appointment_date = VALUES(appointment_date)
          SQL
        end

        def load_max_patient_state
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_patient_state
            SELECT pp.patient_id, MAX(ps.start_date) start_date
            FROM patient_state ps
            INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1 AND pp.voided = 0
            WHERE ps.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND ps.voided = 0
            GROUP BY pp.patient_id
            HAVING start_date IS NOT NULL
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date)
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
                   (
                     SELECT name FROM concept_name
                     WHERE concept_id = (
                     SELECT concept_id FROM program_workflow_state
                     WHERE program_workflow_state_id = patient_state.state
                     LIMIT 1
                     )
                   ) AS cum_outcome,
                   patient_state.start_date, 2
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state IN (#{program_states('Patient transferred out', 'Treatment stopped').to_sql})
              AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND (patient_state.end_date >= #{end_date} OR patient_state.end_date IS NULL)
              AND patient_state.voided = 0
            INNER JOIN temp_max_patient_state AS max_patient_state
              ON max_patient_state.patient_id = patient_program.patient_id
              AND max_patient_state.start_date = patient_state.start_date
            WHERE patients.date_enrolled <= #{end_date}
              AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step = 1)
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load all patients on Pre-ART.
        def load_patients_on_pre_art
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id,
                  CASE
                    WHEN #{current_defaulter_function('patients.patient_id')} = 1 THEN 'Defaulted'
                    ELSE 'Pre-ART (Continue)'
                  END AS cum_outcome,
                  patient_state.start_date, 3
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = (#{program_states('Pre-ART (Continue)').limit(1).to_sql})
              AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND (patient_state.end_date >= #{end_date} OR patient_state.end_date IS NULL)
              AND patient_state.voided = 0
            INNER JOIN temp_max_patient_state AS max_patient_state
              ON max_patient_state.patient_id = patient_program.patient_id
              AND max_patient_state.start_date = patient_state.start_date
            WHERE patients.date_enrolled <= #{end_date}
              AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2))
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load all patients without a state
        def load_patients_without_state
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id,
                   CASE
                      WHEN #{current_defaulter_function('patients.patient_id')} = 1 THEN 'Defaulted'
                      ELSE 'Unknown'
                    END AS cum_outcome,
                   NULL, 4
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            WHERE patients.date_enrolled <= #{end_date}
              AND (patient_program.patient_program_id) NOT IN (
                SELECT patient_program_id
                FROM patient_state
                WHERE start_date < DATE(#{end_date}) + INTERVAL 1 DAY AND voided = 0
              )
              AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3))
            GROUP BY patients.patient_id
            HAVING cum_outcome = 'Defaulted'
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
                   NULL, 5
            FROM temp_earliest_start_date AS patients
            WHERE date_enrolled <= #{end_date}
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4))
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_max_drug_orders)
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Loads all patients who are on treatment
        def load_patients_on_treatment
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id, 'On antiretrovirals', patient_state.start_date, 6
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            /* Get patients' `on ARV` states that are before given date */
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = 7 -- ON ART
              AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND (patient_state.end_date >= #{end_date} OR patient_state.end_date IS NULL)
              AND patient_state.voided = 0
            /* Select only the most recent state out of those retrieved above */
            INNER JOIN temp_max_patient_state AS max_patient_state
              ON max_patient_state.patient_id = patient_program.patient_id
              AND max_patient_state.start_date = patient_state.start_date
            /* HACK: Ensure that the states captured above do correspond have corresponding
                     ARV dispensations. In other words filter out any `on ARVs` states whose
                     dispensation's may have been voided or states that were created manually
                     without any drugs being dispensed.  */
            INNER JOIN temp_min_auto_expire_date AS first_order_to_expire
              ON first_order_to_expire.patient_id = patient_program.patient_id
              AND (first_order_to_expire.auto_expire_date >= #{end_date} OR TIMESTAMPDIFF(DAY,first_order_to_expire.auto_expire_date, #{end_date}) <= #{@definition == 'pepfar' ? 28 : 56})
            WHERE patients.date_enrolled <= #{end_date}
             AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4, 5))
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        def load_without_clinical_contact
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patients.patient_id, 'Defaulted', null, 7
            FROM temp_earliest_start_date AS patients
            INNER JOIN patient_program
              ON patient_program.patient_id = patients.patient_id
              AND patient_program.program_id = 1
              AND patient_program.voided = 0
            /* Get patients' `on ARV` states that are before given date */
            INNER JOIN patient_state
              ON patient_state.patient_program_id = patient_program.patient_program_id
              AND patient_state.state = 7 -- On ART
              AND patient_state.start_date < DATE(#{end_date}) + INTERVAL 1 DAY
              AND (patient_state.end_date >= #{end_date} OR patient_state.end_date IS NULL)
              AND patient_state.voided = 0
            /* Select only the most recent state out of those retrieved above */
            INNER JOIN temp_max_patient_state AS max_patient_state
              ON max_patient_state.patient_id = patient_program.patient_id
              AND max_patient_state.start_date = patient_state.start_date
            INNER JOIN temp_max_patient_appointment app ON app.patient_id = patients.patient_id AND app.appointment_date < #{end_date}
            INNER JOIN temp_min_auto_expire_date AS first_order_to_expire
              ON first_order_to_expire.patient_id = patient_program.patient_id
              AND TIMESTAMPDIFF(DAY,app.appointment_date, first_order_to_expire.auto_expire_date) >= 0
              AND TIMESTAMPDIFF(DAY,app.appointment_date, first_order_to_expire.auto_expire_date) <= 5
              AND first_order_to_expire.auto_expire_date < #{end_date}
              AND TIMESTAMPDIFF(DAY,first_order_to_expire.auto_expire_date, #{end_date}) >= 365
            WHERE patients.date_enrolled <= #{end_date}
            AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4, 5, 6))
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load defaulters
        def load_defaulters
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes
            SELECT patient_id, #{patient_outcome_function('patient_id')}, NULL, 8
            FROM temp_earliest_start_date
            WHERE date_enrolled <= #{end_date}
            AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes WHERE step IN (1, 2, 3, 4, 5, 6, 7))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # rubocop:enable Metrics/MethodLength

        # ===================================
        #  Function Management Region
        # ===================================

        def current_defaulter_function(sql_column)
          case @definition
          when 'moh' then "current_defaulter(#{sql_column}, #{end_date})"
          when 'pepfar' then "current_pepfar_defaulter(#{sql_column}, #{end_date})"
          else raise "Invalid outcomes definition: #{@definition}" # Should never happen but you never know!
          end
        end

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
        def prepare_tables
          create_outcome_table unless check_if_table_exists('temp_patient_outcomes')
          validate_temp_outcome_table
          create_tmp_max_drug_orders_table unless check_if_table_exists('temp_max_drug_orders')
          create_tmp_min_auto_expire_date unless check_if_table_exists('temp_min_auto_expire_date')
          create_temp_max_patient_state unless check_if_table_exists('temp_max_patient_state')
          create_max_patient_appointment_date unless check_if_table_exists('temp_max_patient_appointment')
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

        def validate_temp_outcome_table
          # check if the temp patient outcomes has 4 columns if not drop it and create it gain
          result = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT COUNT(*) AS count
            FROM information_schema.columns
            WHERE table_schema = DATABASE()
            AND table_name = 'temp_patient_outcomes'
          SQL
          drop_temp_patient_outcome_table unless result['count'].to_i == 4
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

        def create_tmp_max_drug_orders_table
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

        def create_tmp_min_auto_expire_date
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_min_auto_expire_date (
              patient_id INT NOT NULL,
              auto_expire_date DATE DEFAULT NULL,
              PRIMARY KEY (patient_id)
            )
          SQL
          create_min_auto_expire_date_indexes
        end

        def create_min_auto_expire_date_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_min_auto_expire_date ON temp_min_auto_expire_date (auto_expire_date)
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

        def create_max_patient_appointment_date
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE TABLE IF NOT EXISTS temp_max_patient_appointment (
              patient_id INT NOT NULL,
              appointment_date DATE NOT NULL,
              PRIMARY KEY (patient_id)
            )
          SQL
          create_max_patient_appointment_date_indexes
        end

        def create_max_patient_appointment_date_indexes
          ActiveRecord::Base.connection.execute <<~SQL
            CREATE INDEX idx_max_patient_appointment_date ON temp_max_patient_appointment (appointment_date)
          SQL
        end

        def update_steps
          ActiveRecord::Base.connection.execute <<~SQL
            UPDATE temp_patient_outcomes SET step = 0 WHERE step > 0
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
          ActiveRecord::Base.connection.execute('TRUNCATE temp_max_patient_appointment')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
