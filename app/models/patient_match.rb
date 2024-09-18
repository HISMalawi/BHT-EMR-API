class PatientMatch < ApplicationRecord
    belongs_to :patient_a, class_name: 'Patient', foreign_key: 'patient_id_a'
    belongs_to :patient_b, class_name: 'Patient', foreign_key: 'patient_id_b'
  
    validates :patient_id_a, :patient_id_b, :match_percentage, presence: true
    validates :match_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :uuid, uniqueness: true
  
    before_save :set_date_changed
  
    private
  
    def set_date_changed
      self.date_changed = Time.now
      self.date_created = Time.now
      self.changed_by = User.current.person_id if User.current 
      self.uuid ||= SecureRandom.uuid
    end
  end
  