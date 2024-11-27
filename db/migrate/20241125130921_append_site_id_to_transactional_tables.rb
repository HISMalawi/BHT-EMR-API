# frozen_string_literal: true

class AppendSiteIdToTransactionalTables < ActiveRecord::Migration[7.0]
  TRANSACTIONAL_TABLES = %w[users person_name drug_ingredients drug_order encounter orders obs patient_program
                            patient_state person_address pharmacies pharmacy_batch_items pharmacy_batches pharmacy_stock_balances pharmacy_stock_verifications relationship].freeze

  def up
    ActiveRecord::Base.transaction do
      @table_constraints = []

      execute_sql <<~SQL
        SET sql_mode = 'ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
      SQL

      TRANSACTIONAL_TABLES.each do |table|
        add_column table, :site_id, :integer, default: current_location unless column_exists?(table, :site_id)

        constraints = execute_sql <<~SQL
          SELECT TABLE_NAME, CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
          from information_schema.KEY_COLUMN_USAGE
          where TABLE_NAME = "#{table}"
          AND CONSTRAINT_SCHEMA = "#{schema}"
        SQL

        constraints.each { @table_constraints << _1 }

        @table_constraints.map do |res|
          next if res['CONSTRAINT_NAME'] == 'PRIMARY'

          next if res['REFERENCED_TABLE_NAME'].nil? || res['REFERENCED_TABLE_NAME'].nil?

          sql = <<~SQL
            ALTER TABLE #{table} DROP FOREIGN KEY `#{res['CONSTRAINT_NAME']}`;
          SQL

          exists = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT * FROM information_schema.TABLE_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = "#{schema}"
            AND TABLE_NAME = "#{table}"
            AND CONSTRAINT_NAME = "#{res['CONSTRAINT_NAME']}"
          SQL

          execute_sql(sql) unless exists.nil?

          begin
            ActiveRecord::Base.connection.execute <<~SQL
              DROP INDEX #{res['CONSTRAINT_NAME']} ON #{table};
            SQL
          rescue StandardError
            nil
          end

          next if primary_key(table).is_a?(Array)

          execute_sql <<~SQL
            ALTER TABLE #{table}
            DROP PRIMARY KEY,
            ADD PRIMARY KEY (#{primary_key(table)}, site_id);
          SQL
        end
      end

      @table_constraints.each do |constraint|
        next if constraint['CONSTRAINT_NAME'] == 'PRIMARY'\
          ||constraint['REFERENCED_TABLE_NAME'].nil?\
           || constraint['REFERENCED_TABLE_NAME'].nil?

        execute_sql <<~SQL
          ALTER TABLE #{constraint['TABLE_NAME']}
          ADD CONSTRAINT `#{constraint['CONSTRAINT_NAME']}`
          FOREIGN KEY #{set_foreign_key(constraint['COLUMN_NAME'], constraint['REFERENCED_TABLE_NAME'])}
          REFERENCES #{constraint['REFERENCED_TABLE_NAME']} #{set_foreign_key(constraint['REFERENCED_COLUMN_NAME'], constraint['REFERENCED_TABLE_NAME'])};
        SQL
      end
    end
  end

  def set_foreign_key(column, table)
    return "(`#{column}`, `site_id`)" if column_exists?(table, :site_id)

    "(`#{column}`)"
  end

  def primary_key(table)
    ActiveRecord::Base.connection.primary_key(table)
  end

  def execute_sql(sql)
    return if sql.nil?

    2.times { print("\n") }
    puts sql

    Rails.logger.info sql
    ActiveRecord::Base.connection.select_all(sql)
  end

  def schema
    User.connection.current_database
  end

  def current_location
    GlobalProperty.find_by(property: 'current_health_center_id').property_value&.to_i
  end
end
