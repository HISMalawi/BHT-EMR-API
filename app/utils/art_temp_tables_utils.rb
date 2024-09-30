# frozen_string_literal: true

# This is a module that can be included in any class that needs to use the methods defined here.
# but essentially this will prepare all temp tables requires in the system

module ArtTempTablesUtils
  def prepare_tables
    prepare_cohort_tables
    prepare_outcome_tables
    prepare_maternal_tables
  end

  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/CyclomaticComplexity
  def prepare_cohort_tables
    create_temp_cohort_members_table unless check_if_table_exists('temp_cohort_members')
    drop_temp_cohort_members_table unless count_table_columns('temp_cohort_members') == 12
    create_tmp_patient_table unless check_if_table_exists('temp_earliest_start_date')
    drop_tmp_patient_table unless count_table_columns('temp_earliest_start_date') == 11
    create_temp_other_patient_types unless check_if_table_exists('temp_other_patient_types')
    drop_temp_other_patient_types unless count_table_columns('temp_other_patient_types') == 1
    create_temp_register_start_date_table unless check_if_table_exists('temp_register_start_date')
    drop_temp_register_start_date_table unless count_table_columns('temp_register_start_date') == 2
    create_temp_order_details unless check_if_table_exists('temp_order_details')
    drop_temp_order_details unless count_table_columns('temp_order_details') == 2
    create_art_start_date unless check_if_table_exists('temp_art_start_date')
    drop_art_start_date unless count_table_columns('temp_art_start_date') == 2
    create_temp_patient_tb_status unless check_if_table_exists('temp_patient_tb_status')
    drop_temp_patient_tb_status unless count_table_columns('temp_patient_tb_status') == 2
    create_temp_latest_tb_status unless check_if_table_exists('temp_latest_tb_status')
    drop_temp_latest_tb_status unless count_table_columns('temp_latest_tb_status') == 2
    create_tmp_max_adherence unless check_if_table_exists('tmp_max_adherence')
    drop_tmp_max_adherence unless count_table_columns('tmp_max_adherence') == 2
    create_temp_pregnant_obs unless check_if_table_exists('temp_pregnant_obs')
    drop_temp_pregnant_obs unless count_table_columns('temp_pregnant_obs') == 3
    create_temp_patient_side_effects unless check_if_table_exists('temp_patient_side_effects')
    drop_temp_patient_side_effects unless count_table_columns('temp_patient_side_effects') == 2
    truncate_cohort_tables
  end

  def prepare_outcome_tables
    [false, true].each do |start|
      create_outcome_table(start:) unless check_if_table_exists("temp_patient_outcomes#{start ? '_start' : ''}")
      unless count_table_columns("temp_patient_outcomes#{start ? '_start' : ''}") == 6
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

  def prepare_maternal_tables
    create_temp_maternal_status unless check_if_table_exists('temp_maternal_status')
    unless count_table_columns('temp_maternal_status') == 2
      drop_temp_maternal_status
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
  #  Cohort Table Management Region
  # ===================================

  def drop_temp_cohort_members_table
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_cohort_members')
    create_temp_cohort_members_table
  end

  def create_temp_cohort_members_table
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_cohort_members (
        patient_id INT PRIMARY KEY,
        date_enrolled DATE,
        earliest_start_date DATE,
        recorded_start_date DATE DEFAULT NULL,
        birthdate DATE DEFAULT NULL,
        birthdate_estimated BOOLEAN,
        death_date DATE,
        gender VARCHAR(32),
        age_at_initiation INT DEFAULT NULL,
        age_in_days INT DEFAULT NULL,
        reason_for_starting_art INT DEFAULT NULL,
        occupation VARCHAR(255) DEFAULT NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    SQL
    create_temp_cohort_members_index
  end

  def create_temp_cohort_members_index
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_id_index ON temp_cohort_members (patient_id)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_enrolled_index ON temp_cohort_members (date_enrolled)'
    )

    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_date_enrolled_index ON temp_cohort_members (patient_id, date_enrolled)'
    )

    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_start_date_index ON temp_cohort_members (earliest_start_date)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_start_date__date_enrolled_index ON temp_cohort_members (patient_id, earliest_start_date, date_enrolled, gender)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_reason ON temp_cohort_members (reason_for_starting_art)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_birthdate_idx ON temp_cohort_members (birthdate)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX member_occupation_idx ON temp_cohort_members (birthdate)'
    )
  end

  def drop_tmp_patient_table
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_earliest_start_date')
    create_tmp_patient_table
  end

  def create_tmp_patient_table
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS temp_earliest_start_date (
         patient_id INT PRIMARY KEY,
         date_enrolled DATE,
         earliest_start_date DATE,
         recorded_start_date DATE DEFAULT NULL,
         birthdate DATE DEFAULT NULL,
         birthdate_estimated BOOLEAN,
         death_date DATE,
         gender VARCHAR(32),
         age_at_initiation INT DEFAULT NULL,
         age_in_days INT DEFAULT NULL,
         reason_for_starting_art INT DEFAULT NULL
      )
    SQL
    create_tmp_patient_table_indexes
  end

  def create_tmp_patient_table_indexes
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX patient_id_index ON temp_earliest_start_date (patient_id)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX date_enrolled_index ON temp_earliest_start_date (date_enrolled)'
    )

    ActiveRecord::Base.connection.execute(
      'CREATE INDEX patient_id__date_enrolled_index ON temp_earliest_start_date (patient_id, date_enrolled)'
    )

    ActiveRecord::Base.connection.execute(
      'CREATE INDEX earliest_start_date_index ON temp_earliest_start_date (earliest_start_date)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX earliest_start_date__date_enrolled_index ON temp_earliest_start_date (patient_id, earliest_start_date, date_enrolled, gender)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX idx_reason_for_art ON temp_earliest_start_date (reason_for_starting_art)'
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX birthdate_idx ON temp_earliest_start_date (birthdate)'
    )
  end

  def drop_temp_register_start_date_table
    ActiveRecord::Base.connection.execute <<-SQL
      DROP TABLE IF EXISTS temp_register_start_date
    SQL
    create_temp_register_start_date_table
  end

  def create_temp_register_start_date_table
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE temp_register_start_date (
        patient_id INT(11) NOT NULL,
        start_date DATE NOT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_temp_register_start_date_table_indexes
  end

  def create_temp_register_start_date_table_indexes
    ActiveRecord::Base.connection.execute 'CREATE INDEX trsd_date ON temp_register_start_date (start_date)'
  end

  def drop_temp_other_patient_types
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_other_patient_types
    SQL
    create_temp_other_patient_types
  end

  def create_temp_other_patient_types
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_other_patient_types (
        patient_id INT(11) NOT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
  end

  def drop_temp_order_details
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_order_details
    SQL
    create_temp_order_details
  end

  def create_temp_order_details
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE temp_order_details (
        patient_id INT NOT NULL,
        start_date DATE NOT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_temp_order_details_indexes
  end

  def create_temp_order_details_indexes
    ActiveRecord::Base.connection.execute 'CREATE INDEX tod_date ON temp_order_details (start_date)'
  end

  def drop_art_start_date
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_art_start_date
    SQL
    create_art_start_date
  end

  def create_art_start_date
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE temp_art_start_date (
        patient_id INT(11) NOT NULL,
        value_datetime DATE NOT NULL,
        PRIMARY KEY (patient_id)
      )
    SQL
    create_art_start_date_indexes
  end

  def create_art_start_date_indexes
    ActiveRecord::Base.connection.execute 'CREATE INDEX tasd_date ON temp_art_start_date (value_datetime)'
  end

  def drop_temp_patient_tb_status
    ActiveRecord::Base.connection.execute(
      'DROP TABLE IF EXISTS `temp_patient_tb_status`'
    )
    create_temp_patient_tb_status
  end

  def create_temp_patient_tb_status
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_patient_tb_status (
        patient_id INT(11) PRIMARY KEY,
        tb_status INT(11)
      )
    SQL
    create_temp_patient_tb_status_indexes
  end

  def create_temp_patient_tb_status_indexes
    ActiveRecord::Base.connection.execute(
      'ALTER TABLE temp_patient_tb_status
       ADD INDEX patient_id_index (patient_id)'
    )
    ActiveRecord::Base.connection.execute(
      'ALTER TABLE temp_patient_tb_status
       ADD INDEX tb_status_index (tb_status)'
    )
    ActiveRecord::Base.connection.execute(
      'ALTER TABLE temp_patient_tb_status
       ADD INDEX patient_id_tb_status_index (patient_id, tb_status)'
    )
  end

  def drop_temp_latest_tb_status
    ActiveRecord::Base.connection.execute(
      'DROP TABLE IF EXISTS temp_latest_tb_status'
    )
    create_temp_latest_tb_status
  end

  def create_temp_latest_tb_status
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_latest_tb_status(
        person_id INT PRIMARY KEY,
        obs_datetime DATETIME
      )
    SQL
  end

  def create_temp_latest_tb_status_indexes
    ActiveRecord::Base.connection.execute 'CREATE INDEX tlts_date ON temp_latest_tb_status(obs_datetime)'
  end

  def drop_tmp_max_adherence
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS tmp_max_adherence')
    create_tmp_max_adherence
  end

  def create_tmp_max_adherence
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE tmp_max_adherence (
        person_id INT PRIMARY KEY,
        visit_date DATE
      )
    SQL
    create_tmp_max_adherence_indexes
  end

  def create_tmp_max_adherence_indexes
    ActiveRecord::Base.connection.execute('CREATE INDEX tma_date ON tmp_max_adherence (visit_date)')
  end

  def drop_temp_pregnant_obs
    ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_pregnant_obs;'
    create_temp_pregnant_obs
  end

  def create_temp_pregnant_obs
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_pregnant_obs(
        person_id INT PRIMARY KEY,
        value_coded INT  NULL,
        obs_datetime DATE NULL
      )
    SQL
    create_temp_pregnant_obs_indexes
  end

  def create_temp_pregnant_obs_indexes
    ActiveRecord::Base.connection.execute 'CREATE INDEX fre_obs_time ON temp_pregnant_obs(obs_datetime);'
  end

  def drop_temp_patient_side_effects
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TABLE IF EXISTS temp_patient_side_effects
    SQL
    create_temp_patient_side_effects
  end

  def create_temp_patient_side_effects
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_patient_side_effects (
        patient_id INT(11) PRIMARY KEY,
        has_se VARCHAR(120) NOT NULL
      )
    SQL
    create_temp_patient_side_effects_indexes
  end

  def create_temp_patient_side_effects_indexes
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_side_effects ON temp_patient_side_effects (patient_id, has_se)
    SQL
  end

  # ===================================
  # Maternal Status Table Management Region
  # ===================================

  def drop_temp_maternal_status
    ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_maternal_status'
    create_temp_maternal_status
  end

  def create_temp_maternal_status
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE temp_maternal_status (
        patient_id INT PRIMARY KEY,
        maternal_status VARCHAR(5) NOT NULL
      )
    SQL
    create_temp_maternal_status_indexes
  end

  def create_temp_maternal_status_indexes
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX idx_maternal_status ON temp_maternal_status (patient_id, maternal_status)
    SQL
  end

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
      moh_cum_outcome VARCHAR(120) NOT NULL,
      moh_outcome_date DATE DEFAULT NULL,
      pepfar_cum_outcome VARCHAR(120) NOT NULL,
      pepfar_outcome_date DATE DEFAULT NULL,
      step INT DEFAULT 0,
      PRIMARY KEY (patient_id)
      )
    SQL
    create_outcome_indexes(start:)
  end

  def create_outcome_indexes(start: false)
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX moh_outcome#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (moh_cum_outcome)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX moh_out_date#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (moh_outcome_date)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX pepfar_outcome#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (pepfar_cum_outcome)
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE INDEX pepfar_out_date#{start ? '_start' : ''} ON temp_patient_outcomes#{start ? '_start' : ''} (pepfar_outcome_date)
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

  # ===================================
  #  Cohort Table Data Management Region
  # ===================================
  def truncate_cohort_tables
    ActiveRecord::Base.connection.execute('TRUNCATE temp_cohort_members')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_earliest_start_date')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_other_patient_types')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_register_start_date')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_order_details')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_art_start_date')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_patient_tb_status')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_latest_tb_status')
    ActiveRecord::Base.connection.execute('TRUNCATE tmp_max_adherence')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_pregnant_obs')
    ActiveRecord::Base.connection.execute('TRUNCATE temp_patient_side_effects')
  end

  # ===================================
  #  Outcome Table Data Management Region
  # ===================================
  def truncate_outcome_tables(start: false)
    ActiveRecord::Base.connection.execute("TRUNCATE temp_patient_outcomes#{start ? '_start' : ''}")
    ActiveRecord::Base.connection.execute("TRUNCATE temp_max_drug_orders#{start ? '_start' : ''}")
    ActiveRecord::Base.connection.execute("TRUNCATE temp_min_auto_expire_date#{start ? '_start' : ''}")
    ActiveRecord::Base.connection.execute("TRUNCATE temp_max_patient_state#{start ? '_start' : ''}")
    ActiveRecord::Base.connection.execute("TRUNCATE temp_current_state#{start ? '_start' : ''}")
    ActiveRecord::Base.connection.execute("TRUNCATE temp_current_medication#{start ? '_start' : ''}")
  end
end
