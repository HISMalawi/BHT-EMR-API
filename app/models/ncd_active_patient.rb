class NcdActivePatient
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :patient_id, type: String
  field :encounter_datetime, type: DateTime 
  field :location_id, type: String
  field :active_patient, type: Hash
  field :last_synced_at, type: DateTime

  # Indexes for better query performance
  index({ patient_id: 1 }, { unique: true })
  index({ location_id: 1 })
  index({ encounter_datetime: -1 })

  # Validations
  validates :patient_id, presence: true
  validates :location_id, presence: true
  validates :active_patient, presence: true
end