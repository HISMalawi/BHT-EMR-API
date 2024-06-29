# frozen_string_literal: true

module ArtService
  module Reports
    module Cohort
      # This is the Cohort Outcome class
      # rubocop:disable Metrics/ClassLength
      class Outcomes
        include ArtTempTablesUtils

        attr_reader :end_date, :definition, :rebuild, :start_date, :prev_date

        def initialize(end_date:, definition: 'moh', **kwargs)
          definition = definition.downcase
          raise ArgumentError, "Invalid outcomes definition: #{definition}" unless %w[moh pepfar].include?(definition)

          start_date = kwargs[:start_date] || (end_date.to_date - 2.months).beginning_of_month
          @end_date = ActiveRecord::Base.connection.quote(end_date.to_date)
          @start_date = ActiveRecord::Base.connection.quote(start_date.to_date)
          @prev_date = ActiveRecord::Base.connection.quote((start_date.to_date - 2.months).beginning_of_month)
          @definition = definition
          @rebuild = kwargs[:rebuild]&.casecmp?('true')
        end

        def update_cummulative_outcomes
          [false, true].each do |start|
            truncate_outcome_tables(start:) if rebuild
            update_steps(start:, portion: false) unless rebuild
            process_data(start:)
          end
        end

        def update_outcomes_by_definition
          [false, true].each do |start|
            update_steps(start:, portion: true)
            load_patients_on_treatment(start:)
            load_without_clinical_contact(start:)
            load_defaulters(start:)
          end
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
        def process_data(start: false)
          denormalize(start:)
          # HIC SUNT DRACONIS: The order of the operations below matters,
          # do not change it unless you know what you are doing!!!
          load_patients_who_died(start:)
          load_other_patient_who_died(start:)
          load_patients_who_stopped_treatment(start:)
          load_patients_without_drug_orders(start:)
          load_patients_on_treatment(start:)
          load_without_clinical_contact(start:)
          load_defaulters(start:)
        end

        # rubocop:disable Metrics/MethodLength

        def denormalize(start: false)
          load_max_drug_orders(start:)
          update_max_drug_orders(start:)
          load_patient_current_medication(start:)
          update_patient_current_medication(start:)
          load_min_auto_expire_date(start:)
          load_max_patient_state(start:)
          load_patient_current_state(start:)
          update_patient_current_state(start:)
        end

        def load_max_drug_orders(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_drug_orders#{start ? '_start' : ''}
            SELECT o.patient_id, MAX(o.start_date) AS start_date, NUll
            FROM orders o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.patient_id
            INNER JOIN drug_order ON drug_order.order_id = o.order_id AND drug_order.quantity > 0
              AND drug_order.drug_inventory_id IN (#{arv_drug})
            WHERE o.order_type_id = 1 -- drug order
              AND o.start_date < (DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'})
              AND o.voided = 0
            GROUP BY o.patient_id
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date), min_order_date = VALUES(min_order_date)
          SQL
        end

        def update_max_drug_orders(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_drug_orders#{start ? '_start' : ''}
            SELECT o.patient_id, MAX(o.start_date) AS start_date, MIN(o.start_date) AS min_order_date
            FROM orders o
            INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = o.patient_id
            INNER JOIN drug_order ON drug_order.order_id = o.order_id AND drug_order.quantity > 0
              AND drug_order.drug_inventory_id IN (#{arv_drug})
            WHERE o.order_type_id = 1 -- drug order
              AND o.start_date < (DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'})
              AND o.start_date >= (DATE(#{start ? prev_date : start_date}) #{start ? '' : '+ INTERVAL 1 DAY'})
              AND o.voided = 0
            GROUP BY o.patient_id
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date), min_order_date = VALUES(min_order_date)
          SQL
        end

        def load_min_auto_expire_date(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_min_auto_expire_date#{start ? '_start' : ''}
            SELECT cm.patient_id, MIN(cm.start_date), MIN(cm.expiry_date), MIN(cm.pepfar_defaulter_date), MIN(cm.moh_defaulter_date)
            FROM temp_current_medication#{start ? '_start' : ''} cm
            GROUP BY cm.patient_id
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date), auto_expire_date = VALUES(auto_expire_date), pepfar_defaulter_date = VALUES(pepfar_defaulter_date), moh_defaulter_date = VALUES(moh_defaulter_date)
          SQL
        end

        def load_max_patient_state(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_max_patient_state#{start ? '_start' : ''}
            SELECT pp.patient_id, MAX(ps.start_date) start_date
            FROM patient_state ps
            INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1 AND pp.voided = 0
            WHERE ps.start_date < DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'}
              AND ps.voided = 0 AND pp.patient_id IN (SELECT patient_id FROM temp_earliest_start_date)
            GROUP BY pp.patient_id
            HAVING start_date IS NOT NULL
            ON DUPLICATE KEY UPDATE start_date = VALUES(start_date)
          SQL
        end

        def load_patient_current_state(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_state#{start ? '_start' : ''}
            SELECT mps.patient_id, cn.name AS cum_outcome, ps.start_date as outcome_date, ps.state, count(DISTINCT(ps.state)) outcomes, MAX(ps.patient_state_id) patient_state_id
            FROM patient_state ps
            INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = 1 AND pp.voided = 0
            INNER JOIN temp_max_patient_state#{start ? '_start' : ''} mps ON mps.patient_id = pp.patient_id AND mps.start_date = ps.start_date
            INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state AND pws.retired = 0
            INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.voided = 0 AND cn.concept_name_type = 'FULLY_SPECIFIED'
            LEFT JOIN patient_state ps2 ON ps.patient_program_id = ps2.patient_program_id AND ps.start_date = ps2.start_date AND ps.date_created < ps2.date_created AND ps2.voided = 0
            AND ps2.start_date < DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'}
            WHERE ps2.patient_program_id IS NULL AND ps.voided = 0
            GROUP BY mps.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), state = VALUES(state), outcomes = VALUES(outcomes), patient_state_id = VALUES(patient_state_id)
          SQL
        end

        def update_patient_current_state(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_state#{start ? '_start' : ''}
            SELECT cs.patient_id, cn.name as cum_outcome, ps.start_date as outcome_date, ps.state, 1, cs.patient_state_id
            FROM patient_state ps
            INNER JOIN temp_current_state#{start ? '_start' : ''} cs ON cs.patient_state_id = ps.patient_state_id
            INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state AND pws.retired = 0
            INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' AND cn.voided = 0
            WHERE ps.voided = 0 AND cs.outcomes > 1
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), state = VALUES(state), outcomes = VALUES(outcomes), patient_state_id = VALUES(patient_state_id)
          SQL
        end

        def load_patient_current_medication(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_medication#{start ? '_start' : ''}
            SELECT mdo.patient_id, d.concept_id, do.drug_inventory_id drug_id,
              CASE
                WHEN do.equivalent_daily_dose IS NULL THEN 1
                WHEN do.equivalent_daily_dose = 0 THEN 1
                WHEN do.equivalent_daily_dose REGEXP '^[0-9]+(\.[0-9]+)?$' THEN do.equivalent_daily_dose
                ELSE 1
              END daily_dose,
              SUM(do.quantity) quantity,
              DATE(mdo.start_date) start_date, null, null, null, null
            FROM temp_max_drug_orders#{start ? '_start' : ''} mdo
            INNER JOIN orders o ON o.patient_id = mdo.patient_id AND o.order_type_id = 1 AND DATE(o.start_date) = DATE(mdo.start_date) AND o.voided = 0
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0 AND do.drug_inventory_id IN (#{arv_drug})
            INNER JOIN drug d ON d.drug_id = do.drug_inventory_id
            GROUP BY mdo.patient_id, do.drug_inventory_id HAVING quantity < 6000
            ON DUPLICATE KEY UPDATE concept_id = VALUES(concept_id), daily_dose = VALUES(daily_dose), quantity=VALUES(quantity), start_date = VALUES(start_date), pill_count = VALUES(pill_count), expiry_date = VALUES(expiry_date), pepfar_defaulter_date = VALUES(pepfar_defaulter_date), moh_defaulter_date = VALUES(moh_defaulter_date);
          SQL
        end

        def update_patient_current_medication(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_current_medication#{start ? '_start' : ''}
            SELECT cm.patient_id, cm.concept_id, cm.drug_id, cm.daily_dose, cm.quantity, cm.start_date,
            COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0) AS pill_count,
            DATE_ADD(cm.start_date, INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY),
            DATE_ADD(DATE_ADD(cm.start_date, INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY), INTERVAL 30 DAY),
            DATE_ADD(DATE_ADD(cm.start_date, INTERVAL (cm.quantity + COALESCE(first_ob.quantity, 0) + COALESCE(SUM(second_ob.value_numeric),0) + COALESCE(SUM(third_ob.value_numeric),0)) / cm.daily_dose DAY), INTERVAL 60 DAY)
            FROM temp_current_medication#{start ? '_start' : ''} cm
            LEFT JOIN (
              SELECT ob.person_id, cm.drug_id,
                SUM(ob.value_numeric) + SUM(CASE
                  WHEN ob.value_text is null then 0
                  WHEN ob.value_text REGEXP '^[0-9]+(\.[0-9]+)?$' then ob.value_text
                  ELSE 0
                END) quantity
              FROM obs ob
              INNER JOIN temp_current_medication#{start ? '_start' : ''} cm ON cm.patient_id = ob.person_id AND cm.start_date = DATE(ob.obs_datetime)
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
        def load_patients_who_died(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patients.patient_id, 'Patient died', patients.outcome_date, 1
            FROM temp_current_state#{start ? '_start' : ''} AS patients
            WHERE patients.outcomes = 1 AND patients.cum_outcome = 'Patient died'
            GROUP BY patients.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        def load_other_patient_who_died(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT tesd.patient_id, 'Patient died', MAX(ps.start_date), 1
            FROM temp_earliest_start_date tesd
            INNER JOIN patient_program pp ON pp.patient_id = tesd.patient_id AND pp.program_id = 1 AND pp.voided = 0
            INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.state = 3 AND ps.voided = 0 AND ps.start_date <= DATE(#{start ? start_date : end_date}) #{start ? '- INTERVAL 1 DAY' : ''}
            WHERE tesd.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step = 1)
            AND tesd.date_enrolled < DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'}
            GROUP BY tesd.patient_id
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Loads all patients with an outcome of transferred out or
        # treatment stopped into temp_patient_outcomes table.
        def load_patients_who_stopped_treatment(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patients.patient_id,
              patients.cum_outcome,
              patients.outcome_date, 2
            FROM temp_current_state#{start ? '_start' : ''} AS patients
            WHERE (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step = 1)
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
        def load_patients_without_drug_orders(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patients.patient_id,
                   'Unknown',
                   NULL, 3
            FROM temp_earliest_start_date AS patients
            WHERE date_enrolled < DATE(#{start ? start_date : end_date}) #{start ? '' : '+ INTERVAL 1 DAY'}
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step IN (1, 2))
              AND (patient_id) NOT IN (SELECT patient_id FROM temp_max_drug_orders#{start ? '_start' : ''})
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Loads all patients who are on treatment
        def load_patients_on_treatment(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patients.patient_id, 'On antiretrovirals', COALESCE(cs.outcome_date, patients.start_date), 4
            FROM temp_min_auto_expire_date#{start ? '_start' : ''} AS patients
            LEFT JOIN temp_current_state#{start ? '_start' : ''} AS cs ON cs.patient_id = patients.patient_id
            WHERE patients.#{@definition == 'pepfar' ? 'pepfar_defaulter_date' : 'moh_defaulter_date'} > DATE(#{start ? start_date : end_date}) #{start ? '- INTERVAL 1 DAY' : ''}
            AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step IN (1, 2, 3))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        def load_without_clinical_contact(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patients.patient_id, 'Defaulted', #{@definition == 'pepfar' ? 'pepfar_defaulter_date' : 'moh_defaulter_date'}, 5
            FROM temp_current_medication#{start ? '_start' : ''} AS patients
            LEFT JOIN temp_current_state#{start ? '_start' : ''} AS cs ON cs.patient_id = patients.patient_id
            WHERE patients.#{@definition == 'pepfar' ? 'pepfar_defaulter_date' : 'moh_defaulter_date'} <= DATE(#{start ? start_date : end_date}) #{start ? '- INTERVAL 1 DAY' : ''}
            AND (patients.patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step IN (1, 2, 3, 4))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # Load defaulters
        def load_defaulters(start: false)
          ActiveRecord::Base.connection.execute <<~SQL
            INSERT INTO temp_patient_outcomes#{start ? '_start' : ''}
            SELECT patient_id, #{patient_outcome_function('patient_id', start)}, NULL, 6
            FROM temp_earliest_start_date
            WHERE date_enrolled < DATE(#{start ? start_date : end_date}) + INTERVAL 1 DAY
            AND (patient_id) NOT IN (SELECT patient_id FROM temp_patient_outcomes#{start ? '_start' : ''} WHERE step IN (1, 2, 3, 4, 5))
            ON DUPLICATE KEY UPDATE cum_outcome = VALUES(cum_outcome), outcome_date = VALUES(outcome_date), step = VALUES(step)
          SQL
        end

        # rubocop:enable Metrics/MethodLength

        # ===================================
        #  Function Management Region
        # ===================================
        def patient_outcome_function(sql_column, start)
          case @definition
          when 'moh' then "patient_outcome(#{sql_column}, #{start ? "'#{start_date.to_date - 1.day}'" : end_date})"
          when 'pepfar' then "pepfar_patient_outcome(#{sql_column}, #{start ? "'#{start_date.to_date - 1.day}'" : end_date})"
          else raise "Invalid outcomes definition: #{@definition}"
          end
        end

        def update_steps(start: false, portion: false)
          ActiveRecord::Base.connection.execute <<~SQL
            UPDATE temp_patient_outcomes#{start ? '_start' : ''} SET step = 0 WHERE step >= #{portion ? 1 : 4}
          SQL
        end

        def arv_drug
          @arv_drug ||= ::Drug.arv_drugs.map(&:drug_id).join(',')
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
