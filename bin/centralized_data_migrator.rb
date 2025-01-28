require 'active_record'
require 'json'
require 'psych'

# Load Database Configuration
database_config = Psych.load(File.read('config/database.yml'), aliases: true).freeze
source_db = database_config['centralized_source_db']['database']
SITE_ID = ActiveRecord::Base.connection.select_one("SELECT property_value
  FROM #{source_db}.global_property
  WHERE property = 'current_health_center_id'")['property_value'].to_i
SITE_USER_MAPPING = Rails.root.join('log', "users_mapping_#{SITE_ID}.json")
File.write(SITE_USER_MAPPING, '{}') unless File.exist?(SITE_USER_MAPPING)

# Query Helper
def query_with_columns(table_name, where_clause = nil, limit = nil, offset = nil)
  query = "SELECT * FROM #{table_name}"
  query += " WHERE #{where_clause}" if where_clause
  query += " LIMIT #{limit}" if limit
  query += " OFFSET #{offset}" if offset

  ActiveRecord::Base.connection.select_all(query).to_a
end

# Process in Batches with Percentage Tracking
def process_in_batches(source_db, table_name, batch_size = 1000, &block)
  total_records = ActiveRecord::Base.connection.select_one("SELECT COUNT(*) AS count FROM #{source_db}.#{table_name}")['count'].to_i
  processed_records = 0

  offset = 0
  loop do
    records = query_with_columns("#{source_db}.#{table_name}", nil, batch_size, offset)
    break if records.blank?

    records.each do |record|
      yield(record)
    end

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

  [:changed_by, :creator, :voided_by].each do |key|
    person_data[key] = get_new_user_id(person_data[key], source_db) if person_data[key]
  end

  existing_person = Person.unscoped.find_by(uuid: person_data[:uuid])
  return existing_person.person_id if existing_person

  new_person = Person.new(person_data)
  new_person.save!
  new_person.id
end

# Generic Populate Function with Percentage Tracking
def populate_records(source_table, target_model, source_db, foreign_keys = {})
  process_in_batches(source_db, source_table) do |record|
    record.symbolize_keys!

    # Update foreign key mappings
    foreign_keys.each do |foreign_key, mapping_method|
      record[foreign_key] = send(mapping_method, record[foreign_key], source_db) if record[foreign_key]
    end

    record[:site_id] = SITE_ID
    record[target_model.primary_key.to_sym] = nil if target_model.to_s != 'Patient' # Reset primary key for insertion

    # Skip if the record already exists
    if target_model.to_s == 'Patient'
      next if target_model.unscoped.where(patient_id: record[:patient_id])
    else
      next if target_model.unscoped.where(uuid: record[:uuid]).exists?
    end

    new_record = target_model.new(record)
    new_record.save(validate: false)
  end
end

# User Migration with Percentage Tracking
def populate_users(source_db)
  site_users = JSON.parse(File.read(SITE_USER_MAPPING))

  process_in_batches(source_db, 'users') do |user|
    user.symbolize_keys!
    old_user_id = user[:user_id]

    next if User.unscoped.exists?(uuid: user[:uuid])

    user[:site_id] = SITE_ID
    user[:user_id] = nil

    [:changed_by, :creator].each do |key|
      user[key] = get_new_user_id(user[key], source_db) if user[key]
    end

    user[:person_id] = create_user_person(user, source_db)

    new_user = User.new(user)

    if new_user.save!(validate: false)
      site_users[old_user_id] = new_user.id
      File.write(SITE_USER_MAPPING, JSON.dump(site_users))
    end
  end
end

# Helper Methods
def get_new_user_id(old_user_id, source_db)
  return unless old_user_id

  user_uuid = query_with_columns("#{source_db}.users", "user_id = #{old_user_id}").first["uuid"]
  User.unscoped.find_by(uuid: user_uuid)&.id
end

def create_user_person(user, source_db)
  person_data = query_with_columns("#{source_db}.person", "person_id = #{user[:person_id]}").first
  populate_person(person_data, source_db)
end

def get_person_id(old_person_id, source_db)
  person_uuid = query_with_columns("#{source_db}.person", "person_id = #{old_person_id}").first['uuid']
  Person.unscoped.find_by_uuid(person_uuid)&.person_id
end

# Main Execution
populate_users(source_db)
populate_records('person', Person, source_db, {creator: :get_new_user_id, changed_by: :get_new_user_id, voided_by: :get_new_user_id })
populate_records('person_name', PersonName, source_db, { person_id: :get_person_id, creator: :get_new_user_id, changed_by: :get_new_user_id, voided_by: :get_new_user_id })
populate_records('person_address', PersonAddress, source_db, { person_id: :get_person_id, creator: :get_new_user_id, voided_by: :get_new_user_id })
populate_records('person_attribute', PersonAttribute, source_db, { person_id: :get_person_id, creator: :get_new_user_id, changed_by: :get_new_user_id, voided_by: :get_new_user_id })
populate_records('patient', Patient, source_db, { patient_id: :get_person_id })
populate_records('patient_identifier', PatientIdentifier, source_db, { patient_id: :get_person_id })
populate_records('patient_program', PatientProgram, source_db, { patient_id: :get_person_id })
populate_records('encounter', Encounter, source_db, { patient_id: :get_person_id })
