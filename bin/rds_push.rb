# frozen_string_literal: true

class << self
  include RdsService
end

def main(database, program_name)
  logger.info("Scraping database [#{database}, #{program_name}]")
  initiate_couch_sync

  program = Program.find_by_name(program_name)

  RdsService::MODELS.each do |model|
    logger.debug("Scanning model: #{model}")
    last_update_time = database_offset(model, database)

    recent_records(model, last_update_time, database).each do |record|
      logger.debug("Handling #{model}(##{record.id})")

      update_time = record_update_time(record)
      # NOTE: Cast dates to string for comparison due to possible invalid
      #       date '0000-00-00 00:00:00' that was being used in old ART issues.
      last_update_time = update_time if update_time.to_s > last_update_time.to_s

      sync_status = find_record_sync_status(record, database)
      if record_already_synced?(record, sync_status)
        logger.debug("Skipping already synced record #{model}(##{record.id})")
        next
      end

      record_doc_id = push_record(record, sync_status&.record_doc_id, program)

      save_record_sync_status(sync_status, record, record_doc_id, database)
    rescue RestClient::Exception => e
      logger.error("Failed to write #{model} ##{record.id} due to exception: #{e.class} - #{e} - #{e.response.body}")
    end

    save_database_offset(model, last_update_time, database)
  end
end

# Attempts to execute passed block with a lock file
def with_lock
  File.open('/tmp/rds_push.lock', File::RDWR | File::CREAT) do |lock_file|
    unless lock_file.flock(File::LOCK_EX | File::LOCK_NB)
      logger.warn 'Another instance is already is running'
      exit 255
    end

    yield
  end
end

with_lock do
  config # Load rds_configuration early to ensure its sanity before doing anything

  config['databases'].each do |database, database_config|
    main(database, database_config['program_name'])
  end
end
