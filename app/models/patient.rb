class Patient < ApplicationRecord
  after_void :void_related_models

  self.table_name = 'patient'
  self.primary_key = 'patient_id'

  has_one :person, foreign_key: :person_id
  has_many :patient_identifiers, foreign_key: :patient_id, dependent: :destroy
  has_many :patient_programs
  has_many :programs, through: :patient_programs
  has_many :relationships, foreign_key: :person_a, dependent: :destroy
  has_many :orders
  has_many :encounters do
    def find_by_date(encounter_date)
      encounter_date ||= Date.today
      all(conditions: ['DATE(encounter_datetime) = DATE(?)', encounter_date])
      # Use the SQL DATE function to compare just the date part
    end
  end

  def void_related_models(reason)
    person.void(reason)
    patient_identifiers.each { |row| row.void(reason) }
    patient_programs.each { |row| row.void(reason) }
    orders.each { |row| row.void(reason) }
    encounters.each { |row| row.void(reason) }
  end
end
