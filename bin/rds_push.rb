# frozen_string_literal: true

require 'logger'
require 'rest-client'
require 'securerandom'

Rails.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger = Rails.logger
RestClient.log = Rails.logger

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
  config # Load configuration early to ensure it's sanity before doing anything

  MODELS.each do |model|
    Rails.logger.debug("Scanning model: #{model}")
    last_update_time = delta(model)

    recent_records(model, last_update_time).each do |record|
      Rails.logger.debug("#{last_update_time} - #{model}: #{record}")

      update_time = record_update_time(record)
      last_update_time = update_time if update_time > last_update_time

      sync_status = find_record_sync_status(record)
      next if record_already_synced?(record, sync_status)

      record_doc_id = push_record(record, sync_status&.record_doc_id)

      save_record_sync_status(sync_status, record, record_doc_id)
    rescue StandardError => e
      Rails.logger.error("Failed to write `#{model}` record: #{record} due to exception: #{e}")
    end

    save_delta(model, last_update_time)
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

  Rails.logger.debug("Saving delta, #{time}, for model: #{model}")

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

  Rails.logger.debug("Pushing record (#{doc_id}) to couch db: #{record}")

  if doc_id
    push_existing_record(record, doc_id)
  else
    push_new_record(record)
  end
end

# Convert record to JSON
def serialize_record(record)
  serialized_record = record.as_json(ignore_includes: true)
  serialized_record['record_type'] = record.class.to_s
  serialized_record.to_json
end

# Push a new record to couch db
#
# @see push_record
def push_new_record(record)
  handle_couch_response do
    RestClient.post(couch_url, record, content_type: :json)
  end
end

def push_existing_record(record, doc_id)
  handle_couch_response do
    RestClient.put("#{couch_url}/#{doc_id}", record, content_type: :json)
  end
end

def create_couch_database
  response = RestClient.put(couch_url, {})
  Rails.logger.debug(response)
end

def couch_url
  protocol = config['couchdb']['protocol']
  username = config['couchdb']['username']
  password = config['couchdb']['password']
  host = config['couchdb']['host']
  port = config['couchdb']['port']
  database = config['couchdb']['database']

  "#{protocol}://#{username}:#{password}@#{host}:#{port}/#{database}"
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

main
