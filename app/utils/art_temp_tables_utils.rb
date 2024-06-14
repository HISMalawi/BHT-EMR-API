# frozen_string_literal: true

# This is a module that can be included in any class that needs to use the methods defined here.
# but essentially this will prepare all temp tables requires in the system

module ArtTempTablesUtils
  def prepare_tables
    prepare_cohort_tables
    prepare_outcome_tables
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/CyclomaticComplexity
  def prepare_cohort_tables; end

  def prepare_outcome_tables
    [false, true].each do |start|
      create_outcome_table(start:) unless check_if_table_exists("temp_patient_outcomes#{start ? '_start' : ''}")
      unless count_table_columns("temp_patient_outcomes#{start ? '_start' : ''}") == 4
        drop_temp_patient_outcome_table(start:)
      end
      unless check_if_table_exists("temp_max_drug_orders#{start ? '_start' : ''}")
        create_temp_max_drug_orders_table(start:)
      end
      unless count_table_columns("temp_max_drug_orders#{start ? '_start' : ''}") == 3
        drop_temp_max_drug_orders_table(start:)
      end
      unless check_if_table_exists("temp_min_auto_expire_date#{start ? '_start' : ''}")
        create_tmp_min_auto_expire_date(start:)
      end
      unless count_table_columns("temp_min_auto_expire_date#{start ? '_start' : ''}") == 5
        drop_tmp_min_auto_expirte_date(start:)
      end
      unless check_if_table_exists("temp_max_patient_state#{start ? '_start' : ''}")
        create_temp_max_patient_state(start:)
      end
      create_temp_current_state(start:) unless check_if_table_exists("temp_current_state#{start ? '_start' : ''}")
      unless check_if_table_exists("temp_current_medication#{start ? '_start' : ''}")
        create_temp_current_medication(start:)
      end
      drop_temp_current_state(start:) unless count_table_columns("temp_current_state#{start ? '_start' : ''}") == 6
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  private

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

  # ===================================
  #  Outcome Table Management Region
  # ===================================

  # ===================================
  #  Outcome Table Management Region
  # ===================================

  def create_temp_current_medication(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_current_medication#{start ? '_start' : ''}(
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
    craete_tmp_current_med_index(start:)
  end

  def craete_tmp_current_med_index(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_cm_concept#{start ? '_start' : ''} ON temp_current_medication#{start ? '_start' : ''} (concept_id)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_cm_drug#{start ? '_start' : ''} ON temp_current_medication#{start ? '_start' : ''} (drug_id)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_cm_date#{start ? '_start' : ''} ON temp_current_medication#{start ? '_start' : ''} (start_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_cm_pepfar#{start ? '_start' : ''} ON temp_current_medication#{start ? '_start' : ''} (pepfar_defaulter_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_cm_moh#{start ? '_start' : ''} ON temp_current_medication#{start ? '_start' : ''} (moh_defaulter_date)
    SQL
  end

  def create_temp_current_state(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_current_state#{start ? '_start' : ''}(
        patient_id INT NOT NULL,
        cum_outcome VARCHAR(120) NOT NULL,
        outcome_date DATE DEFAULT NULL,
        state INT NOT NULL,
        outcomes INT NOT NULL,
        patient_state_id INT NOT NULL,
        PRIMARY KEY(patient_id))
    SQL
    create_current_state_index(start:)
  end

  def create_current_state_index(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_state_name#{start ? '_start' : ''} ON temp_current_state#{start ? '_start' : ''} (cum_outcome)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_state_id#{start ? '_start' : ''} ON temp_current_state#{start ? '_start' : ''} (state)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_state_count#{start ? '_start' : ''} ON temp_current_state#{start ? '_start' : ''} (outcomes)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_patient_state_id#{start ? '_start' : ''} ON temp_current_state#{start ? '_start' : ''} (patient_state_id)
    SQL
  end

  def create_tmp_min_auto_expire_date(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_min_auto_expire_date#{start ? '_start' : ''} (
        patient_id INT NOT NULL,
        start_date DATE DEFAULT NULL,
        auto_expire_date DATE DEFAULT NULL,
        pepfar_defaulter_date DATE DEFAULT NULL,
        moh_defaulter_date DATE DEFAULT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_min_auto_expire_date_indexes(start:)
  end
  # rubocop:enable Metrics/MethodLength

  def drop_temp_current_state(start: false)
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS temp_current_state#{start ? '_start' : ''}")
    create_temp_current_state(start:)
  end

  def drop_temp_patient_outcome_table(start: false)
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS temp_patient_outcomes#{start ? '_start' : ''}")
    create_outcome_table(start:)
  end

  def create_outcome_table(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_patient_outcomes#{start ? '_start' : ''} (
      patient_id INT NOT NULL,
      cum_outcome VARCHAR(120) NOT NULL,
      outcome_date DATE DEFAULT NULL,
      step INT DEFAULT 0,
      PRIMARY KEY (patient_id)
      )
    SQL
    create_outcome_indexes(start:)
  end

  def create_outcome_indexes(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_outcome#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (cum_outcome)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_out_date#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (outcome_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_out_step#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (step)
    SQL
  end

  def drop_temp_max_drug_orders_table(start: false)
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS temp_max_drug_orders#{start ? '_start' : ''}")
    create_temp_max_drug_orders_table(start:)
  end

  def create_temp_max_drug_orders_table(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_max_drug_orders#{start ? '_start' : ''} (
        patient_id INT NOT NULL,
        start_date DATETIME DEFAULT NULL,
        min_order_date DATETIME DEFAULT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_max_drug_orders_indexes(start:)
  end

  def create_max_drug_orders_indexes(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_max_orders#{start ? '_start' : ''} ON temp_max_drug_orders#{start ? '_start' : ''} (start_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_max_min_orders#{start ? '_start' : ''} ON temp_max_drug_orders#{start ? '_start' : ''} (min_order_date)
    SQL
  end

  def drop_tmp_min_auto_expirte_date(start: false)
    ActiveRecord::Base.connection.execute "DROP TABLE temp_min_auto_expire_date#{start ? '_start' : ''}"
    create_tmp_min_auto_expire_date(start:)
  end

  def create_min_auto_expire_date_indexes(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_min_auto_expire_date#{start ? '_start' : ''} ON temp_min_auto_expire_date#{start ? '_start' : ''} (auto_expire_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_min_pepfar#{start ? '_start' : ''} ON temp_min_auto_expire_date#{start ? '_start' : ''} (pepfar_defaulter_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_min_moh#{start ? '_start' : ''} ON temp_min_auto_expire_date#{start ? '_start' : ''} (moh_defaulter_date)
    SQL
  end

  def create_temp_max_patient_state(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_max_patient_state#{start ? '_start' : ''} (
        patient_id INT NOT NULL,
        start_date VARCHAR(15) DEFAULT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_max_patient_state_indexes(start:)
  end

  def create_max_patient_state_indexes(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_max_patient_state#{start ? '_start' : ''} ON temp_max_patient_state#{start ? '_start' : ''} (start_date)
    SQL
  end

  def update_steps(start: false, portion: false)
    ActiveRecord::Base.connection.execute <<~SQL
      UPDATE temp_patient_outcomes#{start ? '_start' : ''} SET step = 0 WHERE step >= #{portion ? 1 : 4}
    SQL
  end
end
