require 'active_record'
require 'json'
require 'psych'
require 'parallel'
require 'sys/proctable'
require 'sys/cpu'
require 'sys/filesystem'
require 'sys/memory'

include Sys

NON_RESET_MODELS = %w[Patient DrugOrder GlobalProperty UserRole UserProperty DrugIngredient
                      LimsAcknowledgementStatus].freeze
NON_LOCATION_ID_MODELS = %w[].freeze
NON_UUID_MODELS = %w[UserRole UserProperty].freeze

# @orphaned_order_id = []

# Load Database Configuration
database_config = Psych.load(File.read('config/database.yml'), aliases: true).freeze
source_db = database_config['centralized_source_db']['database']
SITE_ID = ActiveRecord::Base.connection.select_one("SELECT property_value
  FROM #{source_db}.global_property
  WHERE property = 'current_health_center_id'")['property_value'].to_i
SITE_USER_MAPPING = Rails.root.join('log', "users_mapping_#{SITE_ID}.json")
File.write(SITE_USER_MAPPING, '{}') unless File.exist?(SITE_USER_MAPPING)
Location.current = Location.find_by_location_id(SITE_ID)
user = User.unscoped.first
user['location_id'] = SITE_ID
User.current = user
CURRENT_USER = User.current

def prepare_centralized_db
  puts 'Preparing Centralized database for migration...'

  if ActiveRecord::Base.connection.index_name_exists?(:global_property, :global_property_uuid_index)
    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE global_property DROP INDEX global_property_uuid_index;
    SQL
  end

  # # 1. Drop the foreign key
  # foreign_keys = ActiveRecord::Base.connection.foreign_keys(:user_property).map(&:name)
  # if foreign_keys.include?('user_property')
  #   ActiveRecord::Base.connection.execute <<-SQL
  #     ALTER TABLE user_property
  #     DROP FOREIGN KEY user_property
  #   SQL
  # end

  # # 2. Modify location_id to NOT NULL
  # ActiveRecord::Base.connection.execute <<-SQL
  #   ALTER TABLE user_property
  #   MODIFY COLUMN location_id BIGINT NOT NULL DEFAULT 0
  # SQL

  # # 3. Drop existing primary key
  # ActiveRecord::Base.connection.execute <<-SQL
  #   ALTER TABLE user_property
  #   DROP PRIMARY KEY
  # SQL

  # # 4. Add new primary key including location_id
  # ActiveRecord::Base.connection.execute <<-SQL
  #   ALTER TABLE user_property
  #   ADD PRIMARY KEY (user_id, property, location_id)
  # SQL

  # # 5. Re-add the foreign key
  # ActiveRecord::Base.connection.execute <<-SQL
  #   ALTER TABLE user_property
  #   ADD CONSTRAINT user_property
  #   FOREIGN KEY (user_id) REFERENCES users(user_id)
  # SQL

  existing_columns = ActiveRecord::Base.connection.columns(:global_property).map(&:name)
  unless existing_columns.include?('location_id')
    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE global_property ADD COLUMN location_id INT;
    SQL
  end

  foreign_keys = ActiveRecord::Base.connection.foreign_keys(:drug_ingredient).map(&:name)

  if foreign_keys.include?('ingredient')
    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE drug_ingredient DROP FOREIGN KEY ingredient;
    SQL
  end

  if foreign_keys.include?('combination_drug')
    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE drug_ingredient DROP FOREIGN KEY combination_drug;
    SQL
  end

  return unless ActiveRecord::Base.connection.primary_key(:drug_ingredient)

  ActiveRecord::Base.connection.execute <<~SQL
    ALTER TABLE drug_ingredient DROP PRIMARY KEY;
  SQL
end

# Query Helper
def query_with_columns(table_name, where_clause = nil, limit = nil, offset = nil)
  query = "SELECT * FROM #{table_name}"
  query += " WHERE #{where_clause}" if where_clause
  query += " LIMIT #{limit}" if limit
  query += " OFFSET #{offset}" if offset

  ActiveRecord::Base.connection.select_all(query).to_a
end

# Dynamically determine optimal thread count based on system load
def optimal_threads
  memory_stats = Sys::Memory
  free_memory = memory_stats.total - memory_stats.used
  free_memory_gb = free_memory.to_f / (1024**3)
  memory_usage = (memory_stats.used.to_f / memory_stats.total) * 100

  num_cores = Parallel.physical_processor_count
  max_threads = num_cores - 1

  # Use load_avg as a fallback
  cpu_usage = Sys::CPU.load_avg[0] / num_cores * 100

  disk_usage = Sys::Filesystem.stat('/').percent_used

  thread_boost = [(free_memory / (memory_stats.total * 0.1)).to_i, 4].min
  dynamic_max_threads = num_cores + thread_boost
  min_threads = [(num_cores * 0.25).to_i, 2].max

  thread_count = if cpu_usage < 70 && free_memory > (memory_stats.total * 0.2)
                   [max_threads, dynamic_max_threads].min
                 elsif cpu_usage > 80 || free_memory < (memory_stats.total * 0.05)
                   min_threads
                 else
                   num_cores
                 end

  puts "Using #{thread_count} threads | CPU: #{cpu_usage.round(2)}% | RAM: #{memory_usage.round(2)}% | Free RAM: #{free_memory_gb.round(2)} GB | Disk: #{disk_usage.round(2)}%"

  thread_count
end

# Process in Batches with Dynamic Threads and Percentage Tracking
def process_in_batches(source_db, table_name, batch_size = 100_000)
  if %w[global_property user_role user_property].include?(table_name.to_s)
    batch_ranges = [[0, 100_000]]
  else
    column_name = ActiveRecord::Base.connection.columns(table_name).first.name
    min_max = ActiveRecord::Base.connection.select_one("SELECT MIN(#{column_name}) AS min_id,
                                                        MAX(#{column_name})
                                                        AS max_id FROM #{source_db}.#{table_name}")
    min_id = min_max['min_id'].to_i
    max_id = min_max['max_id'].to_i
    batch_ranges = (min_id..max_id).each_slice(batch_size).to_a
  end

  processed_records = 0
  total_records = ActiveRecord::Base.connection.select_one("SELECT COUNT(*) AS count
                                                            FROM #{source_db}.#{table_name}")['count'].to_i
  num_threads = optimal_threads
  puts "Using #{num_threads} threads for processing #{table_name}..."

  Parallel.each(batch_ranges, in_threads: num_threads) do |batch_range|
    records = if %w[global_property user_role user_property].include?(table_name.to_s)
                query_with_columns("#{source_db}.#{table_name}")
              else
                query_with_columns("#{source_db}.#{table_name}", "#{column_name} >= #{batch_range.first}
                                            AND #{column_name} <= #{batch_range.last}")
              end

    next if records.blank?

    yield(records)

    processed_records += records.size
    percentage = ((processed_records.to_f / total_records) * 100).round(2)
    puts "Processing #{table_name}: #{percentage}% complete (#{processed_records}/#{total_records})"
  end
end

# Populate Person
def populate_person(person_data, source_db)
  person_data.symbolize_keys!
  person_data[:person_id] = nil

  %i[changed_by creator voided_by].each do |key|
    person_data[key] = get_new_user_id(person_data[key], source_db) || 1 if person_data[key]
  end

  existing_person = Person.unscoped.find_by(uuid: person_data[:uuid])
  return existing_person.person_id if existing_person

  person_data.delete(:site_id)
  new_person = Person.new(person_data)
  new_person.location_id = SITE_ID
  new_person.save(validate: false)
  new_person.person_id
end

# Generic Populate Function with Percentage Tracking
def populate_records(source_table, target_model, source_db, foreign_keys = {})
  process_in_batches(source_db, source_table) do |records|
    records.each(&:symbolize_keys!)
    # Fetch only the records that exist in the current batch

    # Update foreign key mappings
    foreign_keys.each do |foreign_key, mapping_method|
      records = send(mapping_method, records, foreign_key, source_db)
    end

    record_keys = case target_model.to_s
                  when 'Patient'
                    records.map { |r| r[:patient_id] }
                  when 'DrugOrder'
                    records.map { |r| r[:order_id] }
                  when 'GlobalProperty'
                    records.map { |r| [r[:property]] }
                  when 'UserRole'
                    records.map { |r| r[:user_id] }
                  when 'UserProperty'
                    records.map { |r| r[:user_id] }
                  when 'Pharmacy'
                    records.map { |r| r[:pharmacy_module_id] }
                  else
                    records.map { |r| r[:uuid] }
                  end

    existing_keys = case target_model.to_s
                    when 'Patient'
                      target_model.unscoped.where(patient_id: record_keys).pluck(:patient_id).to_set
                    when 'DrugOrder'
                      target_model.unscoped.where(order_id: record_keys).pluck(:order_id).to_set
                    when 'GlobalProperty'
                      target_model.unscoped.where(property: record_keys.map(&:first),
                                                  location_id: SITE_ID).pluck(:property, :location_id).to_set
                    when 'UserRole'
                      target_model.unscoped.where(user_id: record_keys, location_id: SITE_ID)
                                  .pluck(:user_id, :role).to_set
                    when 'UserProperty'
                      target_model.unscoped.where(user_id: record_keys, location_id: SITE_ID)
                                  .pluck(:user_id, :property, :location_id)
                    when 'Pharmacy'
                      target_model.unscoped.where(pharmacy_module_id: record_keys, location_id: SITE_ID)
                                  .pluck(:pharmacy_module_id, :location_id)
                    else
                      target_model.unscoped.where(uuid: record_keys).pluck(:uuid).to_set
                    end

    insertable_records = records.reject do |record|
      case target_model.to_s
      when 'Patient'
        existing_keys.include?(record[:patient_id])
      when 'DrugOrder'
        existing_keys.include?(record[:order_id]) || record[:order_id].blank?
      when 'GlobalProperty'
        existing_keys.include?([record[:property], SITE_ID.to_s])
      when 'UserRole'
        existing_keys.include?([record[:user_id], record[:role]])
      when 'UserProperty'
        existing_keys.include?([record[:user_id], record[:property], SITE_ID])
      when 'Pharmacy'
        existing_keys.include?([record[:pharmacy_module_id], SITE_ID])
      else
        existing_keys.include?(record[:uuid])
      end
    end

    next if insertable_records.blank?

    # Reset primary key if necessary
    if insertable_records.first.keys.include?(:date_created)
      insertable_records.each do |record|
        record[target_model.primary_key.to_sym] = nil unless NON_RESET_MODELS.include?(target_model.to_s)
        record[:location_id] = SITE_ID unless NON_LOCATION_ID_MODELS.include?(target_model.to_s)
        record.delete(:site_id) if record.include?(:site_id)
        record[:date_created] = begin
          record[:date_created].to_datetime
        rescue StandardError
          '1900-01-01 00:00:00'
        end
      end
    else
      insertable_records.each do |record|
        record[target_model.primary_key.to_sym] = nil unless NON_RESET_MODELS.include?(target_model.to_s)
        record[:location_id] = SITE_ID unless NON_LOCATION_ID_MODELS.include?(target_model.to_s)
        record.delete(:site_id) if record.include?(:site_id)
        record.delete(:uuid) if NON_UUID_MODELS.include?(target_model.to_s)
        record.delete(:id) if target_model.to_s == 'GlobalProperty'
      end
    end
    User.current = CURRENT_USER
    ActiveRecord::Base.connection_pool.with_connection do
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute('SET FOREIGN_KEY_CHECKS = 0')
        begin
          target_model.unscoped.insert_all!(insertable_records.compact)
        rescue StandardError => e
          puts e.message
          exit
        end
        ActiveRecord::Base.connection.execute('SET FOREIGN_KEY_CHECKS = 1')
      end
    end
  end
end

# User Migration with Percentage Tracking
def populate_users(source_db)
  admin_user = query_with_columns("#{source_db}.users", 'user_id = 1').first
  if User.unscoped.exists?(uuid: admin_user['uuid'])
    admin_user = User.unscoped.find_by(uuid: admin_user['uuid'])
  else
    next_user_id = User.unscoped.maximum(:user_id) + 1
    admin_user['user_id'] = next_user_id
    admin_user['creator'] = next_user_id
    admin_user['changed_by'] = next_user_id
    admin_user['person_id'] = create_user_person(admin_user.symbolize_keys, source_db)
    admin_user['location_id'] = admin_user['facility_code'] = SITE_ID
    admin_user.delete('facility_code') if admin_user.include?('facility_code')
    admin_user.delete('site_id')
    admin_user = User.new(admin_user)
    admin_user.save!(validate: false)
  end

  process_in_batches(source_db, 'users') do |users|
    insertable_records = users.map do |user|
      user.symbolize_keys!

      next if User.unscoped.exists?(uuid: user[:uuid])

      user[:location_id] = SITE_ID
      user.delete(:site_id) if user.include?(:site_id)
      user.delete(:facility_code) if user.include?(:facility_code)
      user[:user_id] = nil

      %i[changed_by creator retired_by].each do |key|
        user[key] = get_new_user_id(user[key], source_db) || admin_user['user_id'] if user[key]
      end

      user[:person_id] = create_user_person(user, source_db) if user[:person_id]

      user
    end
    next if insertable_records.compact.blank?

    User.current = CURRENT_USER
    User.unscoped.insert_all!(insertable_records.compact)
  end
end

# Helper Methods
def fetch_new_ids(records, source_db, table_name, id_column, model, new_id_key)
  old_ids = records.compact.map { |record| record[new_id_key] }.uniq.compact

  return records if old_ids.blank?

  uuid_mapping = query_with_columns(
    "#{source_db}.#{table_name}",
    "#{id_column} IN (#{old_ids.join(',')})"
  ).index_by { |row| row[id_column.to_s] }

  uuid_map = model.unscoped.where(uuid: uuid_mapping.values.map { |row| row['uuid'] })
                  .index_by(&:uuid)
                  .transform_values(&id_column)

  records.compact.each do |record|
    next if record[new_id_key].blank?

    begin
      record[new_id_key] = uuid_map[uuid_mapping[record[new_id_key]]['uuid']]
    rescue StandardError => e
      if %i[creator voided_by].include?(new_id_key)
        record[new_id_key] = uuid_map.values.first
      elsif new_id_key == :order_id
        records.delete(record)
      elsif new_id_key == :patient_id
        records.delete(record)
      elsif new_id_key == :encounter_id
        records.delete(record)
      else
        puts record
        puts e
        puts new_id_key
        exit
      end
    end
  end
  records
end

def get_new_user_id(old_user_id, source_db)
  return unless old_user_id

  user_uuid = query_with_columns("#{source_db}.users", "user_id = #{old_user_id}").first['uuid']
  User.unscoped.find_by(uuid: user_uuid)&.id
end

def create_user_person(user, source_db)
  person_data = query_with_columns("#{source_db}.person", "person_id = #{user[:person_id]}").first
  populate_person(person_data, source_db)
end

def get_encounter_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'encounter', :encounter_id, Encounter, key)
end

def get_new_user_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'users', :user_id, User, key)
end

def get_person_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'person', :person_id, Person, key)
end

def get_order_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'orders', :order_id, Order, key)
end

def get_obs_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'obs', :obs_id, Observation, key)
end

def get_program_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'patient_program', :patient_program_id, PatientProgram, key)
end

def get_new_report_design_id(records, key, source_db)
  fetch_new_ids(records, source_db, 'reporting_report_design', :id, Report, key)
end

def get_location_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'location', :location_id, Location, key)
end

def get_stock_verification_ids(records, key, source_db)
  fetch_new_ids(records, source_db, 'pharmacy_stock_verifications', :id, PharmacyStockVerification, key)
end

def create_users_persons(records, source_db)
  person_ids = records.map { |record| record[:person_id] }.compact

  person_data = query_with_columns(
    "#{source_db}.person",
    "person_id IN (#{person_ids.join(',')})"
  ).index_by { |row| row['person_id'] }

  records.each do |record|
    if person_data[record[:person_id]]
      record[:person_data] =
        populate_person(person_data[record[:person_id]], source_db)
    end
  end

  records
end

def update_group_obs_ids(source_db, foreign_keys = {})
  limit = 100_000
  offset = 0
  total_processed = 0
  total_records = ActiveRecord::Base.connection
                                    .select_one("SELECT COUNT(*) AS count
                                    FROM #{source_db}.obs WHERE obs_group_id IS NOT NULL")['count'].to_i

  ActiveRecord::Base.connection.execute(<<-SQL)
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_obs_update (
      uuid CHAR(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin PRIMARY KEY,
      obs_group_id INT
    );
  SQL

  loop do
    source_obs_grouped = query_with_columns("#{source_db}.obs", 'obs_group_id IS NOT NULL', limit, offset)
    break if source_obs_grouped.blank?

    source_obs_grouped.each(&:symbolize_keys!)

    # Fetch and map foreign keys in bulk
    mapped_records = {}
    foreign_keys.each do |foreign_key, mapping_method|
      mapped_records = send(mapping_method, source_obs_grouped, foreign_key, source_db)
    end

    # Prepare batch updates
    updates = mapped_records.map do |record|
      {
        uuid: record[:uuid],
        obs_group_id: record[:obs_group_id]
      }
    end

    values = updates.map { |r| "('#{r[:uuid]}', #{r[:obs_group_id]})" }.join(', ')
    ActiveRecord::Base.connection.execute("INSERT INTO temp_obs_update (uuid, obs_group_id) VALUES #{values}")

    offset += limit
    total_processed += updates.size
    percentage = ((total_processed.to_f / total_records) * 100).round(2)
    puts "Updating obs_group_id: #{percentage}% complete (#{total_processed}/#{total_records})"
  end
  ActiveRecord::Base.connection.execute('UPDATE obs o
      JOIN temp_obs_update t ON o.uuid = t.uuid
      SET o.obs_group_id = t.obs_group_id;')
ensure
  ActiveRecord::Base.connection.execute('DROP TABLE temp_obs_update;')
end

# Main Execution
prepare_centralized_db
populate_users(source_db)
def populate_group(group)
  Parallel.each(group) do |(table, model, source_db, dependencies)|
    populate_records(table, model, source_db, dependencies)
  end
end

if __FILE__ == $0
  group1_models = {
    user_role: [UserRole, {
      user_id: :get_new_user_ids
    }],
    user_property: [UserProperty, {
      user_id: :get_new_user_ids
    }],
    global_property: [GlobalProperty, {}],
    person: [Person, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    # reporting_report_design: [Report, {
    #   creator: :get_new_user_ids,
    #   changed_by: :get_new_user_ids,
    #   retired_by: :get_new_user_ids
    # }],
    pharmacies: [Pharmacies, {}],
    pharmacy_batch_items: [PharmacyBatchItem, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    pharmacy_batches: [PharmacyBatch, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      location_id: :get_location_ids
    }],
    pharmacy_stock_balances: [PharmacyStockBalance, {}],
    pharmacy_stock_verifications: [PharmacyStockVerification, {}]
    # drug_ingredient: [DrugIngredient, {}]
  }

  group2_models = {
    relationship: [Relationship, {
      creator: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      person_a_id: :get_person_ids,
      person_b_id: :get_person_ids
    }],
    person_name: [PersonName, {
      person_id: :get_person_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    person_address: [PersonAddress, {
      person_id: :get_person_ids,
      creator: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    person_attribute: [PersonAttribute, {
      person_id: :get_person_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    patient: [Patient, {
      patient_id: :get_person_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    # reporting_report_design_resource: [ReportingReportDesignResource, {
    #   creator: :get_new_user_ids,
    #   changed_by: :get_new_user_ids,
    #   retired_by: :get_new_user_ids,
    #   report_design_id: :get_new_report_design_id
    # }],
    pharmacy_obs: [Pharmacy, {
      creator: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      dispensation_obs_id: :get_obs_ids,
      stock_verification_id: :get_stock_verification_ids
    }]
  }

  group3_models = {
    patient_identifier: [PatientIdentifier, {
      patient_id: :get_person_ids,
      creator: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    patient_program: [PatientProgram, {
      patient_id: :get_person_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    encounter: [Encounter, {
      patient_id: :get_person_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      provider_id: :get_person_ids
    }]
  }

  group4_models = {
    orders: [Order, {
      encounter_id: :get_encounter_ids,
      patient_id: :get_person_ids,
      creator: :get_new_user_ids,
      orderer: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      obs_id: :get_obs_ids
    }],
    patient_state: [PatientState, {
      patient_program_id: :get_program_ids,
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }]
  }

  group5_models = {
    obs: [Observation, {
      encounter_id: :get_encounter_ids,
      order_id: :get_order_ids,
      creator: :get_new_user_ids,
      voided_by: :get_new_user_ids,
      person_id: :get_person_ids,
      obs_group_id: :get_obs_ids
    }]
    # ,
    # lims_acknowledgement_statuses: [
    #   LimsAcknowledgementStatus, {
    #     order_id: :get_order_ids,
    #     voided_by: :get_new_user_ids
    #   }
    # ]
  }

  group6_models = {
    drug_order: [DrugOrder, {
      order_id: :get_order_ids
    }]
  }

  groups = [group1_models, group2_models, group3_models, group4_models, group5_models, group6_models]

  groups.each do |group|
    populate_group(group.map { |table, (model, dependencies)| [table, model, source_db, dependencies] })
  end
  update_group_obs_ids(source_db, obs_id: :get_obs_ids,
                                  encounter_id: :get_encounter_ids,
                                  order_id: :get_order_ids,
                                  creator: :get_new_user_ids,
                                  voided_by: :get_new_user_ids,
                                  person_id: :get_person_ids,
                                  obs_group_id: :get_obs_ids)
end
