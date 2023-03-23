# frozen_string_literal: true

module ARTService
  # Art TX Curr Register
  class ARTRegister
    attr_accessor :current_day, :year_ago, :rebuild

    def initialize(date: Date.today, rebuild: false)
      @current_day = date.to_date
      @year_ago = date - 1.year
      @rebuild = rebuild == 'true' ? true : false
    end

    def fetch_register
      file_name = "art_register_#{current_day.strftime('%Y_%m_%d')}.lock"
      lock_file = File.join(Rails.root, 'tmp', file_name)
      delete_older_lock_files
      return if File.exist?(lock_file)

      File.open(lock_file, 'w') { |f| f.write('') }
      create_temp_tables if rebuild
      data = process_data
      File.delete(lock_file) if File.exist?(lock_file)
      data
    rescue e
      File.delete(lock_file) if File.exist?(lock_file)
      raise e
    end

    private

    def delete_older_lock_files
      Dir.glob(File.join(Rails.root, 'tmp', 'art_register_*.lock')).each do |file|
        file_date = file.split('_').last.split('.').first
        file_date = Date.strptime(file_date, '%Y_%m_%d')
        File.delete(file) if file_date < current_day
      end
    end

    def temp_potential_art_register
      ARTService::Reports::CohortBuilder.new.init_temporary_tables(current_day, current_day)
    end

    def temp_art_register_demographics
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE temp_art_register_demographics
        SELECT
            tpar.patient_id,
            pn.given_name,
            pn.family_name,
            pa.city_village,
            pa.state_province,
            pa.township_division,
            COALESCE(pi.identifier, pi2.identifier, 'N/A') AS arv_number,
            pat.value AS cell_phone_number,
            pat2.value AS occupation
        FROM temp_patient_outcomes tpar
        INNER JOIN person p ON p.person_id = tpar.patient_id
        INNER JOIN person_name pn ON pn.person_id = p.person_id AND pn.voided = 0
        INNER JOIN person_address pa ON pa.person_id = p.person_id AND pa.voided = 0
        LEFT JOIN patient_identifier pi ON pi.patient_id = p.person_id AND pi.voided = 0 AND pi.identifier_type = 4 -- ARV NUMBER
        LEFT JOIN patient_identifier pi2 ON pi2.patient_id = p.person_id AND pi2.voided = 0 AND pi2.identifier_type = 17 -- ARCHIVE NUMBER
        LEFT JOIN person_attribute pat ON pat.person_id = p.person_id AND pat.voided = 0  AND pat.person_attribute_type_id = 12 -- CELL PHONE NUMBER
        LEFT JOIN person_attribute pat2 ON pat2.person_id = p.person_id AND pat2.voided = 0  AND pat2.person_attribute_type_id = 13 -- OCCUPATION
        WHERE tpar.cum_outcome IN ('On antiretrovirals')
        GROUP BY tpar.patient_id
      SQL
    end

    def temp_art_register_staging
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE temp_art_register_staging
        SELECT
            tpar.patient_id,
            COALESCE ((SELECT name FROM concept_name WHERE concept_id = art_eligibility.value_coded AND name != '' LIMIT 1), 'Unknown') AS art_eligibility,
            COALESCE ((SELECT name FROM concept_name WHERE concept_id = who_stage.value_coded AND name != '' LIMIT 1), 'Unknown') AS who_stage,
            (CASE WHEN art_initiation_status.value_text IS NOT NULL THEN 'TI' ELSE 'FT' END) AS art_initiation_status,
            COALESCE(kaposis_sacoma.value_coded, 'No')AS kaposis_sarcoma,
            COALESCE((SELECT name FROM concept_name WHERE concept_id = tb.value_coded LIMIT 1), 'Unknown') AS tb,
            (CASE WHEN p.gender = 'M' THEN 'M' ELSE female_maternal_status(tpar.patient_id, p.earliest_start_date) END) AS maternal_status
        FROM temp_patient_outcomes tpar
        INNER JOIN temp_earliest_start_date p ON p.patient_id = tpar.patient_id
        LEFT JOIN obs art_eligibility ON art_eligibility.person_id = tpar.patient_id AND art_eligibility.concept_id = 2743 AND art_eligibility.voided = 0 AND art_eligibility.obs_datetime < DATE('#{current_day}') + INTERVAL 1 DAY
        LEFT JOIN obs who_stage ON who_stage.person_id = tpar.patient_id AND who_stage.concept_id = 7562 AND who_stage.voided = 0 AND who_stage.obs_datetime < DATE('#{current_day}') + INTERVAL 1 DAY
        LEFT JOIN obs art_initiation_status ON art_initiation_status.person_id = tpar.patient_id AND art_initiation_status.concept_id = 7750 AND art_initiation_status.voided = 0 AND art_initiation_status.obs_datetime < DATE('#{current_day}') + INTERVAL 1 DAY
        LEFT JOIN obs kaposis_sacoma ON kaposis_sacoma.person_id = tpar.patient_id AND kaposis_sacoma.concept_id = 2743 AND kaposis_sacoma.voided = 0 AND kaposis_sacoma.value_coded = 507 AND kaposis_sacoma.obs_datetime < DATE('#{current_day}') + INTERVAL 1 DAY
        LEFT JOIN obs tb ON tb.person_id = tpar.patient_id AND tb.concept_id = 2690 AND tb.voided = 0 AND tb.value_coded = 1065 AND tb.obs_datetime < DATE('#{current_day}') + INTERVAL 1 DAY
        WHERE tpar.cum_outcome IN ('On antiretrovirals')
        GROUP BY tpar.patient_id
      SQL
    end

    def fetch_art_register
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
            tpar.*,
            tpar_demographics.*,
            tpar_staging.*,
            tpar_earliest_start_date.*
        FROM temp_patient_outcomes tpar
        INNER JOIN temp_earliest_start_date tpar_earliest_start_date ON tpar_earliest_start_date.patient_id = tpar.patient_id
        INNER JOIN temp_art_register_demographics tpar_demographics ON tpar_demographics.patient_id = tpar.patient_id
        LEFT JOIN temp_art_register_staging tpar_staging ON tpar_staging.patient_id = tpar.patient_id
        GROUP BY tpar.patient_id
      SQL
    end

    def process_data
      create_temp_tables unless tables_temp_exists?
      fetch_art_register.map do |row|
        {
          patient_id: row['patient_id'],
          gender: row['maternal_status'],
          age_at_initiation: row['age_at_initiation'],
          age_group: age_group(row['age_at_initiation'] * 12 || 0),
          year: row['earliest_start_date'].to_date.year,
          quarter: quarter(row['earliest_start_date'].to_date),
          given_name: row['given_name'],
          family_name: row['family_name'],
          city_village: row['city_village'],
          state_province: row['state_province'],
          township_division: row['township_division'],
          arv_number: row['arv_number'],
          phone_number: row['cell_phone_number'],
          occupation: row['occupation'],
          registration_date: row['date_enrolled'],
          earliest_start_date: row['earliest_start_date'],
          outcome: row['cum_outcome'],
          outcome_date: row['outcome_date'],
          initiation_condition: row['art_eligibility'],
          who_stage: row['who_stage'],
          transfer_in: row['art_initiation_status'],
          kaposis_sarcoma: row['kaposis_sarcoma'],
          tb: row['tb']
        }
      end
    end

    def all_female
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT tpo.patient_id
        FROM temp_patient_outcomes tpo
        INNER JOIN temp_earliest_start_date tesd ON tesd.patient_id = tpo.patient_id
        WHERE tpo.cum_outcome IN ('On antiretrovirals') AND LEFT(tesd.gender, 1) = 'F'
      SQL
    end

    TEMP_TABLES = %w[temp_art_register_demographics temp_earliest_start_date temp_art_register_staging temp_patient_outcomes].freeze

    # Create age groups those below 24 months are grouped together as A, 24 months to 15 years as B, 15 older as C
    def age_group(age)
      return 'A' if age < 24
      return 'B' if age >= 24 && age < 180
      return 'C' if age >= 180
    end

    def quarter(date)
      case date.month
      when 1..3
        1
      when 4..6
        2
      when 7..9
        3
      when 10..12
        4
      end
    end

    def arv_concepts
      @arv_concepts ||= 'SELECT concept_id FROM concept_set WHERE concept_set = 1085'
    end

    def order_type
      @order_type ||= 'SELECT order_type_id FROM order_type WHERE name = "Drug order"'
    end

    def tables_temp_exists?
      TEMP_TABLES.each do |table|
        return false unless check_table_exists(table)['result'].positive?
      end
      true
    end

    def check_table_exists(name)
      ActiveRecord::Base.connection.select_one <<~SQL
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_name = '#{name}'
        ) result
      SQL
    end

    def create_temp_tables
      drop_temp_tables
      temp_potential_art_register
      temp_art_register_demographics
      temp_art_register_staging
      create_index
    end

    def create_index
      ActiveRecord::Base.connection.execute <<~SQL
        CREATE INDEX demographics_patient_id_index ON temp_art_register_demographics (patient_id);
      SQL

      ActiveRecord::Base.connection.execute <<~SQL
        CREATE INDEX staging_patient_id_index ON temp_art_register_staging (patient_id);
      SQL
    end

    def drop_temp_tables
      TEMP_TABLES.each do |table|
        drop_table(table)
      end
    end

    def drop_table(name)
      ActiveRecord::Base.connection.execute <<~SQL
        DROP TABLE IF EXISTS #{name};
      SQL
    end
  end
end
