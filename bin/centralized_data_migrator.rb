require 'active_record'
require 'json'
require 'psych'
require 'parallel'
require 'sys/proctable'
require 'sys/cpu'
require 'sys/filesystem'
require 'sys/memory'

include Sys

user = User.first

NON_RESET_MODELS = %w[Patient DrugOrder GlobalProperty UserRole].freeze
@orphaned_order_id = []

# Load Database Configuration
database_config = Psych.load(File.read('config/database.yml'), aliases: true).freeze
source_db = database_config['centralized_source_db']['database']
SITE_ID = ActiveRecord::Base.connection.select_one("SELECT property_value
  FROM #{source_db}.global_property
  WHERE property = 'current_health_center_id'")['property_value'].to_i
SITE_USER_MAPPING = Rails.root.join('log', "users_mapping_#{SITE_ID}.json")
File.write(SITE_USER_MAPPING, '{}') unless File.exist?(SITE_USER_MAPPING)
user['site_id'] =  SITE_ID
User.current = user
CURRENT_USER = User.current

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

  num_cores = Parallel.processor_count
  max_threads = num_cores * 2

  # Use load_avg as a fallback
  cpu_usage = Sys::CPU.load_avg[0] / num_cores * 100

  disk_usage = Sys::Filesystem.stat('/').percent_used

  thread_boost = [(free_memory / (memory_stats.total * 0.1)).to_i, 4].min
  dynamic_max_threads = num_cores + thread_boost
  min_threads = [(num_cores * 0.25).to_i, 2].max

  thread_count = if cpu_usage < 70 && free_memory > (memory_stats.total * 0.1)
                 [max_threads, dynamic_max_threads].max
               elsif cpu_usage > 80 || free_memory < (memory_stats.total * 0.05)
                 min_threads
               else
                 num_cores
               end

  puts "Using #{thread_count} threads | CPU: #{cpu_usage.round(2)}% | RAM: #{memory_usage.round(2)}% | Free RAM: #{free_memory_gb.round(2)} GB | Disk: #{disk_usage.round(2)}%"

  thread_count
end



# Process in Batches with Dynamic Threads and Percentage Tracking
def process_in_batches(source_db, table_name, batch_size = 100_000, &block)

  if table_name == 'global_property'
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
    records = if table_name == 'global_property'
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
  person_data[:site_id] = SITE_ID
  person_data[:person_id] = nil

  %i[changed_by creator voided_by].each do |key|
    person_data[key] = get_new_user_id(person_data[key], source_db) || 1 if person_data[key]
  end

  existing_person = Person.unscoped.find_by(uuid: person_data[:uuid])
  return existing_person.person_id if existing_person

  new_person = Person.new(person_data)
  new_person.save!(validate: false)
  new_person.id
end

# Generic Populate Function with Percentage Tracking
def populate_records(source_table, target_model, source_db, foreign_keys = {})
  ActiveRecord::Base.connection.execute('SET FOREIGN_KEY_CHECKS = 0;')
  ActiveRecord::Base.connection.execute('SET sql_log_bin = 0;')
  process_in_batches(source_db, source_table) do |records|
    Parallel.each(records, in_threads: Parallel.processor_count) do |record|
      record.symbolize_keys!
    end

    # Fetch only the records that exist in the current batch
    record_keys = case target_model.to_s
                  when 'Patient'
                    patient_ids = records.map { |r| r[:patient_id] }
                    uuids = query_with_columns("#{source_db}.person",
                                               "person_id in (#{patient_ids.join(', ')})").pluck('uuid')
                    Person.unscoped.where(uuid: uuids).pluck(:person_id)
                  when 'DrugOrder'
                    order_ids = records.map { |r| r[:order_id] }
                    uuids = query_with_columns("#{source_db}.orders",
                                               "order_id in (#{order_ids.join(', ')})").pluck('uuid')
                    Order.unscoped.where(uuid: uuids).pluck(:order_id)
                  when 'UserRole'
                    records.map { |r| [r[:user_id], r[:role]] }
                  when 'GlobalProperty'
                    records.map { |r| [r[:property]] }
                  else
                    records.map { |r| r[:uuid] }
                  end

    existing_keys = case target_model.to_s
                    when 'Patient'
                      target_model.unscoped.where(patient_id: record_keys).pluck(:patient_id).to_set
                    when 'DrugOrder'
                      target_model.unscoped.where(order_id: record_keys).pluck(:order_id).to_set
                    when 'UserRole'
                      target_model.unscoped.where(user_id: record_keys.map(&:first), role: record_keys.map(&:last),
                                                  site_id: SITE_ID).pluck(:user_id, :role).to_set
                    when 'GlobalProperty'
                      target_model.unscoped.where(property: record_keys.map(&:first),
                                                  site_id: SITE_ID).pluck(:property, :site_id).to_set
                    else
                      target_model.unscoped.where(uuid: record_keys).pluck(:uuid).to_set
                    end
    # Update foreign key mappings
    foreign_keys.each do |foreign_key, mapping_method|
      records = send(mapping_method, records, foreign_key, source_db)
    end

    insertable_records = records.reject do |record|
      case target_model.to_s
      when 'Patient'
        existing_keys.include?(record[:patient_id])
      when 'DrugOrder'
        existing_keys.include?(record[:order_id])
      when 'UserRole'
        existing_keys.include?([record[:user_id], record[:role]])
      when 'GlobalProperty'
        existing_keys.include?([record[:property], SITE_ID])
      else
        existing_keys.include?(record[:uuid])
      end
    end

    next if insertable_records.blank?

    # Reset primary key if necessary
    if insertable_records.first.keys.include?(:date_created)
      insertable_records.each do |record|
        record[target_model.primary_key.to_sym] = nil unless NON_RESET_MODELS.include?(target_model.to_s)
        record[:site_id] = SITE_ID
        record[:date_created] = begin
          record[:date_created].to_datetime
        rescue StandardError
          '1900-01-01 00:00:00'
        end
      end
    else
      insertable_records.each do |record|
        record[target_model.primary_key.to_sym] = nil unless NON_RESET_MODELS.include?(target_model.to_s)
        record[:site_id] = SITE_ID
        record.delete(:id) if target_model.to_s == 'GlobalProperty'
      end
    end
    User.current = CURRENT_USER
    target_model.insert_all!(insertable_records.compact)
  end
  ActiveRecord::Base.connection.execute('SET FOREIGN_KEY_CHECKS = 1;')
end


# User Migration with Percentage Tracking
def populate_users(source_db)
  insertable_records = []
  process_in_batches(source_db, 'users') do |users|
    insertable_records = users.map do |user|
      user.symbolize_keys!

      next if User.unscoped.exists?(uuid: user[:uuid])

      user[:site_id] = SITE_ID
      user[:user_id] = nil

      %i[changed_by creator].each do |key|
        user[key] = get_new_user_id(user[key], source_db) || 1 if user[key]
      end

      user[:person_id] = create_user_person(user, source_db) if user[:person_id]

      user
    end
    next if insertable_records.compact.blank?

    User.current = CURRENT_USER
    User.insert_all!(insertable_records.compact)
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
      puts new_id_key.class
      puts new_id_key == :creator
      p new_id_key

      if %i[creator voided_by].include?(new_id_key)
        record[new_id_key] = uuid_map.values.first
      elsif new_id_key == :order_id
        records.delete(record)
      else
        puts new_id_key
        puts uuid_map
        puts record
        puts e
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

def create_users_persons(records, source_db)
  person_ids = records.map { |record| record[:person_id] }.compact

  person_data = query_with_columns(
    "#{source_db}.person",
    "person_id IN (#{person_ids.join(',')})"
  ).index_by { |row| row['person_id'] }

  records.each do |record|
    record[:person_data] =
populate_person(person_data[record[:person_id]], source_db) if person_data[record[:person_id]]
  end

  records
end

# Main Execution
populate_users(source_db)
# populate_records('user_role', UserRole, source_db)
def populate_group(group)
  Parallel.each(group) do |(table, model, source_db, dependencies)|
    populate_records(table, model, source_db, dependencies)
  end
end

if __FILE__ == $0
  group1_models = {
    global_property: [GlobalProperty, {}],
    person: [Person, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      voided_by: :get_new_user_ids
    }],
    reporting_report_design: [Report, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      retired_by: :get_new_user_ids
    }]
  }

  group2_models = {
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
    reporting_report_design_resource: [ReportingReportDesignResource, {
      creator: :get_new_user_ids,
      changed_by: :get_new_user_ids,
      retired_by: :get_new_user_ids,
      report_design_id: :get_new_report_design_id
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
  puts 'Writing Orphans to file ...'
  `echo #{@orphaned_order_id.to_json} > log/migration_error.log`
end

# populate_records('report_object', )
