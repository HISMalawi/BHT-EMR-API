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
      },
      methods: %i[merge_history art_start_date]
    ))
  end

  def outcome(program, ref_date)
    PatientStateService.new.find_patient_state(program, self, ref_date)
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
      begin
        "#{id[0..4]}-#{id[5..8]}-#{id[9..]}"
      rescue StandardError
        id
      end
    when 9
      begin
        "#{id[0..2]}-#{id[3..6]}-#{id[7..]}"
      rescue StandardError
        id
      end
    when 6
      begin
        "#{id[0..2]}-#{id[3..]}"
      rescue StandardError
        id
      end
    else
      id
    end
  end

  def age(today: Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + (if ((today.month -
          person.birthdate.month) + ((today.day - person.birthdate.day).negative? ? -1 : 0)).negative?
                                                            -1
                                                          else
                                                            0
                                                          end)

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
    obs = Observation.where(person:, concept: concept('Weight'))\
                     .where('DATE(obs_datetime) <= DATE(?)', today)\
                     .order(obs_datetime: :desc)\
                     .limit(1)\
                     .first
    return nil unless obs

    obs.value_numeric || obs.value_text&.to_f
  end

  def void_related_models(reason)
    person.void(reason)
    patient_identifiers.each { |row| row.void(reason) if row['voided'].zero? }
    patient_programs.each { |row| row.void(reason) if row['voided'].zero? }
    orders.each { |row| row.void(reason) if row['voided'].zero? }
    encounters.each { |row| row.void(reason) if row['voided'].zero? }
  end

  def gender
    person.gender
  end

  def identifier(type_name)
    type = PatientIdentifierType.find_by_name(type_name)
    return nil unless type

    PatientIdentifier.where(patient: self, type:)\
                     .order(:date_created)\
                     .last
  end

  def name
    PersonName.where(person_id: patient_id).order(:date_created).last&.to_s
  end

  def merge_history
    MergeAudit.where(primary_id: patient_id).order(:created_at).as_json
  end

  def art_start_date
    return nil if id.blank?

    result = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT patient_start_date(#{id}) AS art_start_date
    SQL
    result['art_start_date'] || nil
  end

  def last_arv_drug_expire_date
    result = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT orders.auto_expire_date
      from orders
      inner join encounter on orders.encounter_id = encounter.encounter_id
       and encounter.voided = 0
      where orders.patient_id = #{id}
      and encounter.program_id = #{Program.find_by_name('HIV PROGRAM').id}
      and orders.voided = 0
      and orders.concept_id in (#{Drug.arv_drugs.map(&:concept_id).join(',')})
      order by orders.auto_expire_date desc
      limit 1
    SQL
result['auto_expire_date']&.to_date || nil if result.present?
  end

  def tpt_status
    return { tpt: nil, completed: false, tb_treatment: false, tpt_init_date: nil, tpt_complete_date: nil } if id.blank?

    ArtService::Reports::Pepfar::TptStatus.new(start_date: Date.today - 6.months, end_date: Date.today,
                                               patient_id: id).find_report
  end
end
