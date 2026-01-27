class PatientRecord
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :patient_id, type: String
  field :encounter_datetime, type: DateTime
  field :record, type: Hash
  field :last_sync_at, type: Time  # Track when the record was last synced
  field :sync_status, type: String, default: 'pending' # Track sync status (pending, synced, failed)
  
  index({ "record.location_id": 1 })
  index({ patient_id: 1 }, { unique: true })
  index({ last_sync_at: 1 })
  index({ sync_status: 1 })
  
  # Add validations
  validates :patient_id, presence: true, uniqueness: true
end