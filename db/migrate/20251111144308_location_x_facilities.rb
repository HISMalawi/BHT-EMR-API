# frozen_string_literal: true

class LocationXFacilities < ActiveRecord::Migration[7.0]
  # set stdout logger for active record

  def change
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = :debug

    # execute 'source /home/brian/projects/BHT-EMR-API/db/migrate/load_csv_mapping.rb'
    load Rails.root.join('db', 'migrate', 'load_csv_mapping.rb')
    load_csv_mapping

    # wrap in a txn
    ActiveRecord::Base.transaction do

      # run sql file
      sql_file_path = Rails.root.join('db', 'migrate', 'merge_locations_x_facilities.sql')
      sql_script = File.read(sql_file_path)
      sql_script.split(/;[\r\n]+/).each do |statement|
        statement.strip!
        next if statement.empty?

        ActiveRecord::Base.connection.execute(statement)
      end

      # get all tables that have location_id linked to facilities
      tables = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT c.TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS c
        WHERE c.COLUMN_NAME = 'location_id'
        AND c.TABLE_SCHEMA = #{ActiveRecord::Base.connection.quote(ActiveRecord::Base.connection.current_database)}
        AND c.DATA_TYPE = 'varchar'
      SQL

      puts "Found #{tables.count} tables to update"

      # disable referential integrity
      ActiveRecord::Base.connection.disable_referential_integrity do
        tables.each do |table|

          # get table type
          table_type = ActiveRecord::Base.connection.select_one <<~SQL
            SHOW FULL TABLES LIKE #{ActiveRecord::Base.connection.quote(table['TABLE_NAME'])}
          SQL

          # skip if table is a view
          next if table_type['Table_type'] == 'VIEW'

          if table['TABLE_NAME'] == 'global_property'
            # remove composite foreign key
            ActiveRecord::Base.connection.execute <<~SQL
              ALTER TABLE global_property DROP INDEX idx_global_property_property_location;
            SQL
          end

          # remove foreign key
          ActiveRecord::Base.connection.foreign_keys(table['TABLE_NAME']).each do |fk|
            if fk.options[:column] == 'location_id'
              puts "Removing foreign key #{fk.name} from table #{table['TABLE_NAME']}"
              ActiveRecord::Base.connection.remove_foreign_key(table['TABLE_NAME'], fk.name)
            end
          end

          ActiveRecord::Base.connection.execute <<~SQL
            SET sql_mode = '';
          SQL

          ActiveRecord::Base.connection.execute <<~SQL
            UPDATE #{table['TABLE_NAME']} tl
              INNER JOIN temp_facility_x_location_map flm ON tl.location_id = flm.facility_code
            SET tl.location_id = flm.location_id
          SQL


          # change column type to integer
          ActiveRecord::Base.connection.execute <<~SQL
            ALTER TABLE #{table['TABLE_NAME']} 
              MODIFY COLUMN location_id INT
          SQL

          # update foreign key
          ActiveRecord::Base.connection.execute <<~SQL
            ALTER TABLE #{table['TABLE_NAME']} 
              ADD CONSTRAINT #{table['TABLE_NAME']}_location_id_fk 
              FOREIGN KEY (location_id) REFERENCES location (location_id)
          SQL
        end
      end

      ActiveRecord::Base.connection.execute 'SET sql_mode = "STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION";'

      # drop temporary table
      ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_facility_x_location_map'

      puts 'Migration completed successfully!'
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace.join("\n")
    raise ActiveRecord::Rollback
  end
end
