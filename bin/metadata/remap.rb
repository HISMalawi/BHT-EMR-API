# frozen_string_literal: true

# The script will merge two openmrs databases. It merges metadata and its transactional tables.
#
# 1. Create a new database
# 2. Load the master metadata into the new database
# 3. For Each Metadata table
#    3.1. Select data from slave table that does not exist in master (using UUID)
#    3.2. Insert the data into the master table
#    3.3. Create a temp_mapping table to indicate the mapping between the slave and master table
#    3.4. Dump the master metadata into the slave database
# 4. For Each Transactional table
#    4.1. Update the transactional table to use the new UUIDs from the temp_mapping table
require 'active_record'

# verbose logging
ActiveRecord::Base.logger = Logger.new($stdout)
LOGGER = Logger.new($stdout)

class SlaveBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :primary } # comes from database.yml
end

class MasterBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :metadata_server_local }
end

class MetadataBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :metadata_server } # comes from database.yml
end

METADATA_TABLES = %i[concept concept_name concept_set concept_answer concept_datatype concept_derived
                     concept_description concept_map concept_name_tag concept_name_tag_map concept_numeric concept_proposal concept_proposal_tag_map concept_set_derived concept_source concept_state_conversion concept_synonym concept_word encounter_type patient_identifier_type order_type person_attribute_type program program_workflow program_workflow_state relationship_type drug privilege location role].freeze

# 11887

## Read and parse the YAML file
def txn_remap_config
  yaml_path = Rails.root.join('bin', 'metadata', 'txn_remap_config.yaml')
  YAML.load_file(yaml_path).with_indifferent_access
end

def table_columns(table:)
  SlaveBase.connection.select_all("SHOW COLUMNS FROM #{table}")
end

def log(message)
  LOGGER.info "\n============================================\n #{message} ... \n============================================"
end

def masterdb
  MasterBase.connection.current_database
end

def slavedb
  SlaveBase.connection.current_database
end

def table_pk(table:)
  SlaveBase.connection.select_one("SHOW KEYS FROM #{table} WHERE Key_name = 'PRIMARY'")['Column_name']
end

def quote_uuids(uuids)
  uuids.map do |uuid|
    ActiveRecord::Base.connection.quote(uuid)
  end.join(', ')
end

def create_temp_mapping_table(table:)
  # drop if exists
  MasterBase.connection.execute("DROP TABLE IF EXISTS temp_remap_#{table}")

  pk = table_pk(table:)
  # get datatype of pk
  pk_type = SlaveBase.connection.select_one("SHOW COLUMNS FROM #{table} WHERE Field = '#{pk}'")['Type']
  pk_type = 'INT' if pk_type.include?('int')
  pk_type = 'VARCHAR(255)' if pk_type.include?('varchar')

  sql = <<~SQL
    CREATE TABLE IF NOT EXISTS temp_remap_#{table} (
      id INT PRIMARY KEY AUTO_INCREMENT,
      old_id #{pk_type},
      new_id #{pk_type}
    )
  SQL
  MasterBase.connection.execute(sql)
end

def create_master_database
  SlaveBase.connection.execute('CREATE DATABASE IF NOT EXISTS openmrs_metadata;')
end

def load_master_metadata
  # dump metadata tables
  log('Getting latest metadata')
  path = Rails.root.join('tmp', 'metadata.sql').to_s
  puts `bin/dump_metadata.sh #{path}`

  # load it in the masterdb
  log('Loading metadata into master database')
  config = MasterBase.configurations.find_db_config(:metadata_server_local).configuration_hash
  puts `mysql -u #{config[:username]} -p#{config[:password]} #{config[:database]} < #{path} -f`

  # cleanup
  File.delete(path)
end

def load_diff(table:)
  has_uuid = table_columns(table:).any? { |c| c['Field'] == 'uuid' }

  log("Table #{table} does not have uuid. Skipping") unless has_uuid
  return unless has_uuid

  # uuids where not in master
  log("Loading diff for #{table}")
  sql = format('SELECT uuid FROM %<table>s WHERE uuid NOT IN (SELECT uuid FROM %<master>s.%<table>s)', table:,
                                                                                                       master: masterdb)
  diff = SlaveBase.connection.select_all(sql)

  log("Found #{diff.count} diff records in #{table}")
  diff.map { |r| r['uuid'] }
end

def update_master(table:, diff:)
  return if diff.nil? || diff.empty?

  # disable foreign key checks
  MasterBase.connection.execute('SET FOREIGN_KEY_CHECKS = 0')

  # all columns except primary key. it should auto increment
  pk = table_pk(table:)
  columns = table_columns(table:).reject { |c| c['Field'] == pk }

  columns = columns.map { |c| c['Field'] }.join(', ')

  # insert into master
  uuids = quote_uuids(diff)

  log("Inserting diff records for #{table.upcase} into master database")
  sql = <<~SQL
    INSERT INTO %<table>s (#{columns})#{' '}
      SELECT #{columns}#{' '}
      FROM %<slavedb>s.%<table>s#{' '}
      WHERE uuid IN (%<uuids>s)
  SQL

  MasterBase.connection.execute(format(sql, pk:, slavedb:, table:, uuids:))
end

def create_mapping_table(table:, diff:)
  return if diff.nil? || diff.empty?

  # create temp_mapping table
  log("Saving mapping data for #{table}")
  create_temp_mapping_table(table:)

  pk = table_pk(table:)

  diff = quote_uuids(diff)

  # insert into temp_mapping table
  sql = <<~SQL
    INSERT INTO temp_remap_%<table>s (old_id, new_id)#{' '}
      SELECT %<pk>s,
      (
        SELECT %<pk>s FROM %<masterdb>s.%<table>s#{' '}
        WHERE uuid = %<slavedb>s.%<table>s.uuid
      )#{' '}
      FROM %<slavedb>s.%<table>s#{' '}
      WHERE uuid IN (%<diff>s)
  SQL
  formatted = format(sql, pk:, masterdb:, slavedb:, table:, diff:)
  MasterBase.connection.execute(formatted)
end

def update_tx_tables
  # disable foreign key checks
  SlaveBase.connection.execute('SET FOREIGN_KEY_CHECKS = 0')

  txn_remap_config.each do |table, config|
    config.each do |c|
      column = c[:column]
      ref = c[:ref]

      ref = "temp_remap_#{ref}"

      log("Updating #{column} for table #{table}")
      sql = <<~SQL
        UPDATE %<table>s
        SET %<column>s = (
          SELECT new_id FROM %<masterdb>s.%<ref>s#{' '}
            WHERE old_id = %<table>s.%<column>s
        )
        WHERE %<column>s IN (
          SELECT old_id FROM %<masterdb>s.%<ref>s
        )#{'      '}
      SQL
      formatted = format(sql, table:, column:, ref:, masterdb:)
      SlaveBase.connection.execute(formatted)
    end
  end
  SlaveBase.connection.execute('SET FOREIGN_KEY_CHECKS = 1')
end

def load_metadata_to_slave
  log('Loading metadata into slave database')
  master_config = MasterBase.configurations.find_db_config(:metadata_server_local).configuration_hash
  slave_config = SlaveBase.configurations.find_db_config(:primary).configuration_hash

  sql = "mysqldump -u #{master_config[:username]} -p#{master_config[:password]} #{master_config[:database]} | mysql -u #{slave_config[:username]} -p#{slave_config[:password]} #{slave_config[:database]}"

  puts `#{sql}`
end

begin
  create_master_database
  MasterBase.transaction do
    load_master_metadata
    METADATA_TABLES.each do |table|
      diff = load_diff(table:)
      update_master(table:, diff:)
      create_mapping_table(table:, diff:)
    end
    load_metadata_to_slave
    update_tx_tables
    log "
        MERGE COMPLETE 🍾🍾🍾🍾
        🚨🚨🚨🚨🚨 FINAL STEP:
        UPDATE THE METADATA FILE (openmrs_metadata_1_7.sql) WITH YOUR DATA AND COMMIT
    "
  end
rescue StandardError => e
  puts e.message
  MasterBase.connection.rollback_db_transaction
end
