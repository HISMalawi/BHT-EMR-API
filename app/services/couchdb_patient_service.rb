require 'rest-client'
require 'json'
require 'yaml'

class CouchdbPatientService
  CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'application.yml')))
  COUCHDB_URL = CONFIG['COUCHDB_URL']
  PATIENTS_DB = 'patients_records'

  class << self
    # Check if CouchDB is configured
    def couchdb_configured?
      COUCHDB_URL.present?
    end

    def ensure_db_exists(db_name = PATIENTS_DB)
      if couchdb_configured?
        RestClient.put("#{COUCHDB_URL}/#{db_name}", '')
      end
      true
    rescue RestClient::PreconditionFailed
      true # Database already exists
    rescue => e
      Rails.logger.error "CouchDB error: #{e.message}"
      false
    end

    def get_patient_record(patient_ids: nil, patient_id: nil)
      ensure_db_exists
      if patient_ids.present?
        # Handle multiple patient IDs
        ids = patient_ids.is_a?(String) ? patient_ids.split(',') : patient_ids
        get_multiple_patients(ids)
      elsif patient_id.present?
        # Handle single patient ID
        get_single_patient(patient_id)
      else
        raise ArgumentError, 'Missing patient identifier'
      end
    rescue => e
      Rails.logger.error "Error getting patient record: #{e.message}"
      patient_ids.present? ? [] : nil
    end

    def get_latest_encounter_date_changed(db_name = 'patients_records')
      unless couchdb_configured?
        Rails.logger.warn "CouchDB not configured. Cannot fetch latest encounter date."
        return nil
      end

      ensure_db_exists(db_name)
      
      # Create the correct index
      create_encounter_date_index(db_name)
      
      query = {
        selector: {
          encounter_date_changed: { "$exists": true, "$ne": nil }
        },
        sort: [{ encounter_date_changed: "desc" }],
        limit: 1,
        use_index: "encounter_date_changed_simple",
        fields: ["encounter_date_changed"]
      }
      
      response = RestClient.post(
        "#{COUCHDB_URL}/#{db_name}/_find",
        query.to_json,
        { content_type: :json, accept: :json }
      )
      
      result = JSON.parse(response.body)
      
      if result['docs'].any?
        doc = result['docs'].first
        return doc['encounter_date_changed']
      else
        return nil
      end
    rescue RestClient::ExceptionWithResponse => e
      error_message = "Error querying latest encounter date: #{e.response&.body || e.message}"
      Rails.logger.error error_message
      return nil
    rescue StandardError => e
      error_message = "Unexpected error: #{e.message}"
      Rails.logger.error error_message
      return nil
    end

    def create_encounter_date_index(db_name)
      return unless couchdb_configured?

      # Check if the correct index already exists
      begin
        response = RestClient.get("#{COUCHDB_URL}/#{db_name}/_index")
        indexes = JSON.parse(response.body)
        
        # Look for an index with the correct field structure
        existing_index = indexes['indexes'].find do |idx| 
          idx['name'] == 'encounter_date_changed_simple' &&
          idx['def'] && 
          idx['def']['fields'] == ['encounter_date_changed']
        end
        
        if existing_index
          Rails.logger.info "Correct index encounter_date_changed_simple already exists"
          return
        end
      rescue => e
        Rails.logger.warn "Could not check existing indexes: #{e.message}"
      end

      # Create index with ONLY the field name - no sort direction
      index_doc = {
        index: {
          fields: ["encounter_date_changed"],  # JUST the field name
          partial_filter_selector: {
            encounter_date_changed: { "$exists": true, "$ne": nil }
          }
        },
        name: "encounter_date_changed_simple",
        ddoc: "encounter_date_changed_simple",
        type: "json"
      }

      response = RestClient.post(
        "#{COUCHDB_URL}/#{db_name}/_index",
        index_doc.to_json,
        { content_type: :json, accept: :json }
      )
      
      result = JSON.parse(response.body)
      Rails.logger.info "Index creation result: #{result['result']}"
      
      # Wait for index to be built
      if result['result'] == 'created'
        Rails.logger.info "New index encounter_date_changed_simple is ready."
        sleep(1)  # Give CouchDB time to build the index
      end
      
    rescue RestClient::ExceptionWithResponse => e
      if e.response.code == 409
        Rails.logger.info "Index already exists - continuing..."
      else
        Rails.logger.error "Error creating index: #{e.response&.body || e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "Unexpected error creating index: #{e.message}"
    end

    # Method to sync from external source to CouchDB
    def sync_patient_to_couchdb(patient_data, patient_id)
      unless couchdb_configured?
        Rails.logger.warn "CouchDB not configured. Skipping sync."
        return { success: false, error: 'CouchDB not configured' }
      end

      ensure_db_exists
      save_patient_record(patient_data, patient_id)
      { success: true }
    rescue => e
      Rails.logger.error "Error syncing patient to CouchDB: #{e.message}"
      { success: false, error: e.message }
    end

    # Utility method for bulk operations
    def bulk_update_patients(patient_records)
      unless couchdb_configured?
        Rails.logger.warn "CouchDB not configured. Skipping bulk update."
        return { success: false, error: 'CouchDB not configured' }
      end

      docs = patient_records.map do |record|
        record.merge({
          'last_sync_at' => Time.current.iso8601,
          'sync_status' => 'synced'
        })
      end

      bulk_payload = { docs: docs }.to_json

      response = RestClient.post(
        "#{COUCHDB_URL}/#{PATIENTS_DB}/_bulk_docs",
        bulk_payload,
        { content_type: :json, accept: :json }
      )
      
      { success: true, response: JSON.parse(response.body) }
    rescue => e
      Rails.logger.error "Error in bulk update: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def get_multiple_patients(patient_ids)
      return false unless couchdb_configured?
      # Use CouchDB _all_docs endpoint with keys parameter
      keys_payload = { keys: patient_ids }.to_json
      
      response = RestClient.post(
        "#{COUCHDB_URL}/#{PATIENTS_DB}/_all_docs?include_docs=true",
        keys_payload,
        { content_type: :json, accept: :json }
      )

      result = JSON.parse(response.body)
      
      # Extract documents, filter out missing ones
      records = result['rows']
        .reject { |row| row['error'] == 'not_found' }
        .map { |row| row['doc'] }

      # Handle missing patients by creating them
      found_ids = records.map { |doc| doc['patientID'] }
      missing_ids = patient_ids - found_ids
      
      missing_ids.each do |missing_id|
        new_record = build_patient_record(missing_id)
        records << new_record if new_record
      end

      records
    end

    def get_single_patient(patient_id)
      if couchdb_configured?
        begin
          # Try to fetch existing document
          patient_identifier = PatientIdentifier.where(patient_id: patient_id, identifier_type: 3)
          identifier = patient_identifier[0][:identifier]
          response = RestClient.get("#{COUCHDB_URL}/#{PATIENTS_DB}/#{identifier}")
          JSON.parse(response.body)
        rescue RestClient::NotFound
          # Patient doesn't exist, build new record
          build_patient_record(patient_id)
        end
      else
        build_patient_record(patient_id)
      end
    end

    def build_patient_record(patient_id)
      # This would call your existing BuildPatientRecordService or create a new one
      record_data = BuildPatientRecordService.build_patient_record(patient_id)
      
      # Save to CouchDB if successfully built
      if record_data
        save_patient_record(record_data, patient_id)
        record_data
      else
        nil
      end
    rescue => e
      Rails.logger.error "Failed to build patient record for #{patient_id}: #{e.message}"
      nil
    end

    def save_patient_record(record_data, patient_id)
      return unless couchdb_configured?

      # Ensure the document has the required CouchDB fields
      doc_data = record_data.as_json.merge({
        '_id' => record_data[:ID] || record_data.dig(:record, :ID),
        'last_sync_at' => Time.current.iso8601,
        'sync_status' => 'synced'
      })

      # Check if document exists to get _rev
      begin
        existing_doc = RestClient.get("#{COUCHDB_URL}/#{PATIENTS_DB}/#{patient_id}")
        doc_data['_rev'] = JSON.parse(existing_doc.body)['_rev']
      rescue RestClient::NotFound
        # New document, no _rev needed
      end

      RestClient.put(
        "#{COUCHDB_URL}/#{PATIENTS_DB}/#{patient_id}",
        doc_data.to_json,
        { content_type: :json, accept: :json }
      )
    end
  end
end