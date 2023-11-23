# frozen_string_literal: true

class ARTService::Reports::Cohort::Outcomes
  attr_reader :end_date

  def initialize(end_date:, definition: 'moh')
    definition = definition.downcase
    raise ArgumentError, "Invalid outcomes definition: #{definition}" unless %w[moh pepfar].include?(definition)

    @end_date = end_date.to_date
    @definition = definition
  end

  def update_cummulative_outcomes
    initialize_table

    # HIC SUNT DRACONIS: The order of the operations below matters,
    # do not change it unless you know what you are doing!!!
    load_patients_who_died
    load_patients_who_stopped_treatment
    load_patients_on_pre_art
    load_patients_without_state
    load_patients_without_drug_orders
    load_patients_on_treatment
    load_defaulters
  end

  private

  def arv_drugs_concept_set
    @arv_drugs_concept_set ||= ConceptSet.where(set: Concept.find_by_name('Antiretroviral drugs'))
                                         .select(:concept_id)
  end

  def drug_order_type
    @drug_order_type ||= OrderType.find_by_name('Drug order')
  end

  def program_states(*names)
    ProgramWorkflowState.joins(:program_workflow)
                        .joins(:concept)
                        .merge(ProgramWorkflow.where(program: hiv_program))
                        .merge(Concept.joins(:concept_names)
                                      .merge(ConceptName.where(name: names)))
                        .select(:program_workflow_state_id)
  end

  def hiv_program
    @hiv_program ||= Program.find_by_name('HIV Program')
  end

  def initialize_table
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_patient_outcomes
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_patient_outcomes (
        patient_id INT(11) PRIMARY KEY,
        cum_outcome VARCHAR(120) NOT NULL,
        outcome_date DATE DEFAULT NULL
      )
    SQL

    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_outcomes ON temp_patient_outcomes (patient_id, cum_outcome, outcome_date)
    SQL
  end

  # Loads all patiens with an outcome of died as of given date
  # into the temp_patient_outcomes table.
  def load_patients_who_died
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patients.patient_id, 'Patient died', patient_state.start_date
      FROM temp_earliest_start_date AS patients
      INNER JOIN patient_program
        ON patient_program.patient_id = patients.patient_id
        AND patient_program.program_id = #{hiv_program.program_id}
        AND patient_program.voided = 0
      INNER JOIN patient_state
        ON patient_state.patient_program_id = patient_program.patient_program_id
        AND patient_state.state = (#{program_states('Patient died').limit(1).to_sql})
        AND patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
        AND patient_state.voided = 0
      WHERE patients.date_enrolled <= #{date}
      GROUP BY patients.patient_id
    SQL
  end

  # Loads all patients with an outcome of transferred out or
  # treatment stopped into temp_patient_outcomes table.
  def load_patients_who_stopped_treatment
    date = ActiveRecord::Base.connection.quote(end_date)

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
             patient_state.start_date
      FROM temp_earliest_start_date AS patients
      INNER JOIN patient_program
        ON patient_program.patient_id = patients.patient_id
        AND patient_program.program_id = #{hiv_program.program_id}
        AND patient_program.voided = 0
      INNER JOIN patient_state
        ON patient_state.patient_program_id = patient_program.patient_program_id
        AND patient_state.state IN (#{program_states('Patient transferred out', 'Treatment stopped').to_sql})
        AND patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
        AND (patient_state.end_date >= #{date} OR patient_state.end_date IS NULL)
        AND patient_state.voided = 0
      INNER JOIN (
        SELECT patient_program_id, MAX(start_date) AS start_date
        FROM patient_state
        WHERE patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
          AND patient_state.voided = 0
        GROUP BY patient_program_id
      ) AS max_patient_state
        ON max_patient_state.patient_program_id = patient_state.patient_program_id
        AND max_patient_state.start_date = patient_state.start_date
      WHERE patients.date_enrolled <= #{date}
        AND patients.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
      GROUP BY patients.patient_id
    SQL
  end

  # Load all patients on Pre-ART.
  def load_patients_on_pre_art
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patients.patient_id,
             IF(#{current_defaulter_function('patients.patient_id')} = 1,
                'Defaulted',
                'Pre-ART (Continue)'),
             patient_state.start_date
      FROM temp_earliest_start_date AS patients
      INNER JOIN patient_program
        ON patient_program.patient_id = patients.patient_id
        AND patient_program.program_id = #{hiv_program.program_id}
        AND patient_program.voided = 0
      INNER JOIN patient_state
        ON patient_state.patient_program_id = patient_program.patient_program_id
        AND patient_state.state = (#{program_states('Pre-ART (Continue)').limit(1).to_sql})
        AND patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
        AND (patient_state.end_date >= #{date} OR patient_state.end_date IS NULL)
        AND patient_state.voided = 0
      INNER JOIN (
        SELECT patient_program_id, MAX(start_date) AS start_date
        FROM patient_state
        WHERE patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
          AND patient_state.voided = 0
        GROUP BY patient_program_id
      ) AS max_patient_state
        ON max_patient_state.patient_program_id = patient_state.patient_program_id
        AND max_patient_state.start_date = patient_state.start_date
      WHERE patients.date_enrolled <= #{date}
        AND patients.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
      GROUP BY patients.patient_id
    SQL
  end

  # Load all patients without a state
  def load_patients_without_state
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patients.patient_id,
             IF(#{current_defaulter_function('patients.patient_id')} = 1, 'Defaulted', 'Unknown'),
             NULL
      FROM temp_earliest_start_date AS patients
      INNER JOIN patient_program
        ON patient_program.patient_id = patients.patient_id
        AND patient_program.program_id = #{hiv_program.program_id}
        AND patient_program.voided = 0
      WHERE patients.date_enrolled <= #{date}
        AND patient_program.patient_program_id NOT IN (
          SELECT patient_program_id
          FROM patient_state
          WHERE start_date < (DATE(#{date}) + INTERVAL 1 DAY)
            AND voided = 0
        )
        AND patients.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
      GROUP BY patients.patient_id
    SQL
  end

  # Load all patients without drug orders or have drug orders
  # without a quantity.
  def load_patients_without_drug_orders
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patients.patient_id,
             'Unknown',
             NULL
      FROM temp_earliest_start_date AS patients
      WHERE date_enrolled <= #{date}
        AND patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
        AND patient_id NOT IN (
          SELECT patient_id
          FROM orders
          LEFT JOIN drug_order USING (order_id)
          WHERE start_date < (DATE(#{date}) + INTERVAL 1 DAY)
            AND quantity > 0
            AND order_type_id = #{drug_order_type.order_type_id}
            AND concept_id IN (#{arv_drugs_concept_set.to_sql})
        )
    SQL
  end

  # Loads all patients who are on treatment
  def load_patients_on_treatment
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patients.patient_id, 'On antiretrovirals', patient_state.start_date
      FROM temp_earliest_start_date AS patients
      INNER JOIN patient_program
        ON patient_program.patient_id = patients.patient_id
        AND patient_program.program_id = #{hiv_program.program_id}
        AND patient_program.voided = 0
      /* Get patients' `on ARV` states that are before given date */
      INNER JOIN patient_state
        ON patient_state.patient_program_id = patient_program.patient_program_id
        AND patient_state.state = (#{program_states('On antiretrovirals').limit(1).to_sql})
        AND patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
        AND (patient_state.end_date >= #{date} OR patient_state.end_date IS NULL)
        AND patient_state.voided = 0
      /* Select only the most recent state out of those retrieved above */
      INNER JOIN (
        SELECT patient_program_id, MAX(start_date) AS start_date
        FROM patient_state
        WHERE patient_state.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
          AND patient_state.voided = 0
        GROUP BY patient_program_id
      ) AS max_patient_state
        ON max_patient_state.patient_program_id = patient_state.patient_program_id
        AND max_patient_state.start_date = patient_state.start_date
      /* HACK: Ensure that the states captured above do correspond have corresponding
               ARV dispensations. In other words filter out any `on ARVs` states whose
               dispensation's may have been voided or states that were created manually
               without any drugs being dispensed.  */
      INNER JOIN (
        SELECT orders.patient_id, MIN(orders.auto_expire_date) AS auto_expire_date
        FROM orders
        INNER JOIN drug_order USING (order_id)
        INNER JOIN (
          SELECT patient_id, MAX(start_date) AS start_date
          FROM orders INNER JOIN drug_order USING (order_id)
          WHERE order_type_id = #{drug_order_type.order_type_id}
            AND concept_id IN (#{arv_drugs_concept_set.to_sql})
            AND start_date < (DATE(#{date}) + INTERVAL 1 DAY)
            AND quantity > 0
            AND voided = 0
            AND patient_id IN (SELECT patient_id FROM temp_earliest_start_date)
            AND patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
          GROUP BY patient_id
        ) AS max_drug_orders
          ON max_drug_orders.patient_id = orders.patient_id
          AND max_drug_orders.start_date = orders.start_date
        WHERE order_type_id = #{drug_order_type.order_type_id}
          AND concept_id IN (#{arv_drugs_concept_set.to_sql})
          AND orders.start_date < (DATE(#{date}) + INTERVAL 1 DAY)
          AND quantity > 0
          AND voided = 0
          AND orders.patient_id IN (SELECT patient_id FROM temp_earliest_start_date)
          AND orders.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
        GROUP BY patient_id
      ) AS first_order_to_expire
        ON (first_order_to_expire.auto_expire_date >= #{date}
            OR DATEDIFF(#{date}, DATE(first_order_to_expire.auto_expire_date)) <= #{@definition == 'pepfar' ? 28 : 56})
        AND first_order_to_expire.patient_id = patient_program.patient_id
      WHERE patients.date_enrolled <= #{date}
        AND patients.patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
      GROUP BY patients.patient_id
    SQL
  end

  # Load defaulters
  def load_defaulters
    date = ActiveRecord::Base.connection.quote(end_date)

    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_outcomes
      SELECT patient_id,
             #{patient_outcome_function('patient_id')},
             NULL
      FROM temp_earliest_start_date
      WHERE date_enrolled <= #{date}
        AND patient_id NOT IN (SELECT patient_id FROM temp_patient_outcomes)
    SQL
  end

  def current_defaulter_function(sql_column)
    case @definition
    when 'moh' then "current_defaulter(#{sql_column}, #{ActiveRecord::Base.connection.quote(end_date)})"
    when 'pepfar' then "current_pepfar_defaulter(#{sql_column}, #{ActiveRecord::Base.connection.quote(end_date)})"
    else raise "Invalid outcomes definition: #{@definition}" # Should never happen but you never know!
    end
  end

  def patient_outcome_function(sql_column)
    case @definition
    when 'moh' then "patient_outcome(#{sql_column}, #{ActiveRecord::Base.connection.quote(end_date)})"
    when 'pepfar' then "pepfar_patient_outcome(#{sql_column}, #{ActiveRecord::Base.connection.quote(end_date)})"
    else raise "Invalid outcomes definition: #{@definition}"
    end
  end
end
