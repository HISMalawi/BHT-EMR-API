require 'rest-client'
require 'json'
require 'yaml'

module CouchdbSync
  CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'application.yml')))
  COUCHDB_URL = CONFIG['COUCHDB_URL']

  def ensure_db_exists(db_name)
    RestClient.put("#{COUCHDB_URL}/#{db_name}", '')
  rescue RestClient::PreconditionFailed
    # Database already exists
  end

  def sync_to_couchdb(doc_data, db_name, doc_id)
    ensure_db_exists(db_name)

    # If updating, fetch _rev
    begin
      existing_doc = RestClient.get("#{COUCHDB_URL}/#{db_name}/#{doc_id}")
      doc_data["_rev"] = JSON.parse(existing_doc.body)["_rev"]
    rescue RestClient::NotFound
      # First insert
    end

    RestClient.put(
      "#{COUCHDB_URL}/#{db_name}/#{doc_id}",
      doc_data.to_json,
      { content_type: :json, accept: :json }
    )
  end
end
