# frozen_string_literal: true

require 'logger'
require 'rest-client'

LOGGER = Logger.new(STDOUT)
ActiveRecord::Base.logger = LOGGER
RestClient.log = LOGGER

APPLICATION_CONFIG_PATH = Rails.root.join('config/application.yml')
DATABASE_CONFIG_PATH = Rails.root.join('config/database.yml').to_s
DELTA_STATE_PATH = Rails.root.join('log/rds-sync-state.yml')

MODELS = [Person, PersonAttribute, PersonAddress, PersonName, Patient,
          PatientIdentifier, Encounter, Observation, Order, DrugOrder,
          PatientProgram, PatientState].freeze

TIME_EPOCH = '1970-01-01'.to_time

# These models are missing a `date_changed` field...
# They probably are not meant to be changed after creation.
IMMUTABLE_MODELS = [PersonAddress, PatientIdentifier, Observation, Order].freeze

def main
  MODELS.each do |model|
    LOGGER.debug("Scanning model: #{model}")
    last_update_time = delta(model)

    recent_records(model, last_update_time).each do |record|
      LOGGER.debug("#{last_update_time} - #{model}: #{record}")

      update_time = record_update_time(record)
      last_update_time = update_time if update_time > last_update_time

      sync_status = find_record_sync_status(record)
      next if record_already_synced?(record, sync_status)

      record_doc_id = push_record(record, sync_status&.record_doc_id)

      save_record_sync_status(sync_status, record, record_doc_id)
    rescue StandardError => e
      LOGGER.error("Failed to write `#{model}` record: #{record} due to exception: #{e}")
    end

    save_delta(model, last_update_time)
  end

  initiate_couch_sync
end

# Attempts to execute passed block with a lock file
def with_lock
  File.open('/tmp/rds_push.lock', File::RDWR | File::CREAT) do |lock_file|
    unless lock_file.flock(File::LOCK_EX | File::LOCK_NB)
      raise 'Another instance is already is running'
    end

    yield
  end
end

def delta(model)
  @delta ||= DELTA_STATE_PATH.exist? ? YAML.load_file(DELTA_STATE_PATH) : {}
  @delta[model.to_s] || TIME_EPOCH
end

# Load database configuration
def config
  return @config if @config

  couchdb_config = YAML.load_file(APPLICATION_CONFIG_PATH)['couchdb']
  database_config = YAML.load_file(DATABASE_CONFIG_PATH)

  raise 'couchdb config not found in in `application.yml`' unless couchdb_config

  @config = {
    'database' => database_config['secondary'] || database_config['development'],
    'couchdb' => couchdb_config
  }
end

def save_delta(model, time)
  return if delta(model) == time

  @delta[model.to_s] = time

  Dir.mkdir(DELTA_STATE_PATH.parent) unless DELTA_STATE_PATH.parent.exist?

  LOGGER.debug("Saving delta, #{time}, for model: #{model}")

  File.open(DELTA_STATE_PATH, 'w') do |fin|
    fin.write(@delta.to_yaml)
  end
end

def recent_records(model, delta)
  # HACK: person address seems to be missing `date_changed` field so we
  # fall back to the existing `date_created`
  return model.where('date_created > ?', delta) if immutable_model?(model)

  return model.joins(:order).where('date_created > ?', delta) if model == DrugOrder

  model.where('date_changed > ?', delta)
end

def model(name)
  name.constantize
end

def immutable_model?(model, instance = false)
  model = model.class if instance

  IMMUTABLE_MODELS.include?(model)
end

# Returns the last time this record was updated
def record_update_time(record)
  # HACK: Models like PersonAddress are missing the preferred
  #   `date_changed` field thus we are falling back to date_created
  return record.date_created if immutable_model?(record, true)

  return record.order.date_created if record.class == DrugOrder

  record.date_changed
end

def find_record_sync_status(record)
  RecordSyncStatus.where(record_type: RecordType.find_by_name(record.class.to_s),
                         record_id: record.id)\
                  .first
end

def record_already_synced?(record, sync_status)
  return false unless sync_status

  record_update_time(record) <= sync_status.updated_at
end

def save_record_sync_status(sync_status, record, record_doc_id)
  time = Time.now

  if sync_status
    sync_status.update(updated_at: time)
    return sync_status
  end

  RecordSyncStatus.create(
    record_type: RecordType.find_by_name(record.class.to_s),
    record_doc_id: record_doc_id,
    record_id: record.id,
    created_at: time,
    updated_at: time
  )
end

# Pushes a record to couch db
#
# @param {record} - An ActiveRecord object to push to CouchDB
# @param {doc_id} - An optional couch document id which if specified triggers
#                   an update of the couch document with record.
#
# @returns  - A couch document id for the pushed record
def push_record(record, doc_id = nil)
  record = serialize_record(record)

  LOGGER.debug("Pushing record (#{doc_id}) to couch db: #{record}")

  if doc_id
    push_existing_record(record, doc_id)
  else
    push_new_record(record)
  end
end

# Convert record to JSON
def serialize_record(record)
  # HACK: Temporarily transform id on the record for the serialization
  # process as we do not know what the id field actually maps to
  # (eg id on Person maps to person_id and on PersonAttribute to person_attribute_type)
  site_id = GlobalProperty.find_by_property('current_health_center_id').property_value
  record_id = record.id
  record.id = "#{record_id}00000#{site_id}".to_i

  serialized_record = record.as_json(ignore_includes: true)
  serialized_record['record_type'] = record.class.to_s

  record.id = record_id # Restore original id

  if record.class == Encounter && record.program.nil?
    # HACK: Apparently this script may be run on old applications
    # that use the old openmrs standard that has no program
    # specific encounters. Thus we manually have to set the program
    # id using the value specified in the config file.
    program_name = config['couchdb']['local']['program']
    raise 'program_name not found in couch config: application.yml' unless program_name

    program = Program.find_by_name(program_name)
    raise 'Invalid program name in couch config: application.yml' unless program

    serialized_record['program_id'] = program.id
  end

  serialized_record.to_json
end

# Push a new record to couch db
#
# @see push_record
def push_new_record(record)
  handle_couch_response do
    RestClient.post(local_couch_database_url, record, content_type: :json)
  end
end

def push_existing_record(record, doc_id)
  handle_couch_response do
    RestClient.put("#{local_couch_database_url}/#{doc_id}", record, content_type: :json)
  end
end

def create_couch_database
  response = RestClient.put(local_couch_url, {})
  LOGGER.debug(response)
end

def local_couch_url
  couch_config = config['couchdb']['local']
  protocol = couch_config['protocol']
  username = couch_config['username']
  password = couch_config['password']
  host = couch_config['host']
  port = couch_config['port']

  "#{protocol}://#{username}:#{password}@#{host}:#{port}"
end

def local_couch_host_url
  couch_config = config['couchdb']['local']
  protocol = couch_config['protocol']
  host = couch_config['host']
  port = couch_config['port']

  "#{protocol}://#{host}:#{port}"
end

def local_couch_database_url
  "#{local_couch_url}/#{config['couchdb']['local']['database']}"
end

# Local couch url but without any auth information
def bare_local_couch_database_url
  "#{local_couch_host_url}/#{config['couchdb']['local']['database']}"
end

def master_couch_url
  couch_config = config['couchdb']['master']
  protocol = couch_config['protocol']
  username = couch_config['username']
  password = couch_config['password']
  host = couch_config['host']
  port = couch_config['port']

  "#{protocol}://#{username}:#{password}@#{host}:#{port}"
end

def master_couch_host_url
  couch_config = config['couchdb']['master']
  protocol = couch_config['protocol']
  host = couch_config['host']
  port = couch_config['port']

  "#{protocol}://#{host}:#{port}"
end

def master_couch_database_url
  "#{master_couch_url}/#{config['couchdb']['master']['database']}"
end

def bare_master_couch_database_url
  couch_config = config['couchdb']['master']
  database = couch_config['database']

  "#{master_couch_host_url}/#{database}"
end

def initiate_couch_sync
  request = {
    'source' => bare_local_couch_database_url,
    'target' => bare_master_couch_database_url,
    'continuous' => true
  }

  return if already_in_sync?(request)

  url = "#{local_couch_url}/_replicate"

  RestClient.post(url, request.to_json, content_type: :json,
                                        referer: local_couch_host_url)
end

def already_in_sync?(sync_params)
  response = RestClient.get("#{local_couch_url}/_active_tasks/replications")

  JSON.parse(response.body).each do |replication|
    LOGGER.debug([replication['source'], replication['target']])
    is_in_sync = (replication['source'].include?(sync_params['source'])\
                  && replication['target'].include?(sync_params['target']))

    next unless is_in_sync

    LOGGER.debug('Replication job already running in CouchDB')
    return true
  end

  false
end

# Handle response from couch db
def handle_couch_response
  response = JSON.parse(yield)
  response['id']
rescue RestClient::NotFound => e
  reason = JSON.parse(e.response.body)['reason']
  return create_couch_database if reason.casecmp?('Database does not exist.')

  raise e
end

with_lock do
  config # Load configuration early to ensure its sanity before doing anything

  main
end
