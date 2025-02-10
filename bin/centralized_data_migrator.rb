require 'active_record'
require 'json'
require 'psych'
require 'parallel'

user = User.first

NON_RESET_MODELS = %w[Patient DrugOrder GlobalProperty UserRole].freeze

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

# Query Helper
def query_with_columns(table_name, where_clause = nil, limit = nil, offset = nil)
  query = "SELECT * FROM #{table_name}"
  query += " WHERE #{where_clause}" if where_clause
  query += " LIMIT #{limit}" if limit
  query += " OFFSET #{offset}" if offset
  
  ActiveRecord::Base.connection.select_all(query).to_a
end

# Process in Batches with Percentage Tracking
def process_in_batches(source_db, table_name, batch_size = 1_000, &block)
  total_records = ActiveRecord::Base.connection.select_one("SELECT COUNT(*) AS count FROM #{source_db}.#{table_name}")['count'].to_i
  processed_records = 0

  offset = 0
  loop do
    records = query_with_columns("#{source_db}.#{table_name}", nil, batch_size, offset)
    break if records.blank?

    yield(records)

    processed_records += records.size
    percentage = ((processed_records.to_f / total_records) * 100).round(2)
    puts "Processing #{table_name}: #{percentage}% complete (#{processed_records}/#{total_records})"

    offset += batch_size
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
         record[:date_created] = begin
           record[:date_created].to_datetime
         rescue StandardError
           '1900-01-01 00:00:00'
         end
      end
    else
      insertable_records.each do |record|
        record[target_model.primary_key.to_sym] = nil unless NON_RESET_MODELS.include?(target_model.to_s)
        record.delete(:id) if target_model.to_s == 'GlobalProperty'
      end
    end
    target_model.insert_all!(insertable_records.compact)
  end
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
    return if insertable_records.compact.blank?

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
    record[new_id_key] = uuid_map[uuid_mapping[record[new_id_key]]['uuid']]
  end
  records
end

def get_new_user_id(old_user_id, source_db)
  return unless old_user_id

  user_uuid = query_with_columns("#{source_db}.users", "user_id = #{old_user_id}").first["uuid"]
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
end

# populate_records('report_object', )
