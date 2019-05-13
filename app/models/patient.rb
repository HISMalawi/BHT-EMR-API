# frozen_string_literal: true

class Patient < VoidableRecord
  include ModelUtils

  after_void :void_related_models

  NPID_NAME = 'National id'
  LEGACY_NPID_NAME = 'Old national id'

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

  def as_json(options = {})
    super(options.merge(
      include: {
        person: {
          include: {
            names: {},
            addresses: {},
            person_attributes: {
              methods: %i[type]
            }
          }
        },
        # programs: {},
        patient_identifiers: {
          methods: %i[type]
        }
      }
    ))
  end

  def national_id
    id_types = PatientIdentifierType.where(name: [NPID_NAME, LEGACY_NPID_NAME])
    id_obj = patient_identifiers.find_by(identifier_type: id_types)
    id_obj ? (id_obj.identifier || '') : ''
  end

  def national_id_with_dashes
    id = national_id
    length = id.length
    case length
    when 13
      id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
    when 9
      id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
    when 6
      id[0..2] + "-" + id[3..-1] rescue id
    else
      id
    end
  end

  def age(today: Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + ((today.month -
          person.birthdate.month) + ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = person.birthdate
    if person.birthdate_estimated == 1\
      && birth_date.month == 7\
      && birth_date.day == 1\
      && today.month < birth_date.month\
      && person.date_created.year == today.year
      patient_age + 1
    else
      patient_age
    end
  end

  def age_in_months(today = Date.today)
    years = (today.year - person.birthdate.year)
    months = (today.month - person.birthdate.month)
    (years * 12) + months
  end

  def weight(today: Date.today)
    obs = Observation.where(person: person, concept: concept('Weight'))\
                     .where('DATE(obs_datetime) <= DATE(?)', today)\
                     .order(obs_datetime: :desc)\
                     .limit(1)\
                     .first
    return nil unless obs

    obs.value_numeric || obs.value_text&.to_f
  end

  def void_related_models(reason)
    person.void(reason)
    patient_identifiers.each { |row| row.void(reason) }
    patient_programs.each { |row| row.void(reason) }
    orders.each { |row| row.void(reason) }
    encounters.each { |row| row.void(reason) }
  end

  def gender
    person.gender
  end

  def identifier(type_name)
    type = PatientIdentifierType.find_by_name(type_name)
    return nil unless type

    PatientIdentifier.where(patient: self, type: type)\
                     .order(:date_created)\
                     .last
  end

  def name
    PersonName.where(person_id: patient_id).order(:date_created).last&.to_s
  end
end
