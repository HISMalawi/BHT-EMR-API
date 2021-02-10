# frozen_string_literal: true

class FilingNumberService
  include ModelUtils

  # Find patients that have a (non-archived) filing number that are eligible
  # for archiving.
  #
  # Search order is as follows:
  #   1. Patients with outcome 'Patient died'
  #   2. Patients with outcome 'Patient transferred out'
  #   3. Patients with outcome 'Treatment stopped'
  #   4. Patients with outcome 'Defaulted'
  def find_archiving_candidates(offset, limit)
    patients = patients_to_be_archived_based_on_waste_state offset, limit
    build_archive_candidates patients
  end

  # Current filing number format does not allow numbers exceeding this value
  PHYSICAL_FILING_NUMBER_LIMIT = 999_999

  # Search for an available filing number
  #
  # Source: NART#app/models/patient_identifiers and NART#lib/patient_service
  def find_available_filing_number(type)
    filing_number_type = patient_identifier_type(type)

    prefix = filing_number_prefixes[0][0..4] if type.match?(/(Filing)/i)
    prefix = filing_number_prefixes[1][0..4] if type.match?(/Archived/i)

    last_identifier = PatientIdentifier.where(type: filing_number_type)\
                                       .order(identifier: :desc)\
                                       .first\
                                       &.identifier

    next_id = last_identifier.blank? ? 1 : last_identifier[5..-1].to_i + 1

    # HACK: Ensure we are not exceeding filing number limits
    if type.match?(/^Filing.*/i) && next_id > filing_number_limit
      return nil
    elsif next_id > PHYSICAL_FILING_NUMBER_LIMIT
      raise "At physical filing number limit: #{next_id} > #{PHYSICAL_FILING_NUMBER_LIMIT}"
    end

    prefix + next_id.to_s.rjust(5, '0')
  end

  # Archives patient with given filing number
  def archive_patient_by_filing_number(filing_number)
    identifier = PatientIdentifier.find_by type: patient_identifier_type('Filing number'),
                                           identifier: filing_number
    return unless identifier

    identifier.void('Filing number re-assigned to another patient')

    PatientIdentifier.create type: patient_identifier_type('Archived Filing Number'),
                             identifier: find_available_filing_number('Archived filing number'),
                             patient: identifier.patient,
                             location_id: Location.current.location_id
  end

  # Restores a patient onto the filing system by assigning the patient a new filing number
  #
  # Sort of the reversal of `archive_patient_by_filing_number`
  #
  # Source: This method was originally NART#lib/patient_service#next_filing_number_to
  #         be_archived.
  def restore_patient(patient, filing_number)
    ActiveRecord::Base.transaction do
      active_filing_number_identifier_type = patient_identifier_type('Filing Number')
      dormant_filing_number_identifier_type = patient_identifier_type('Archived filing number')

      return nil if filing_number[5..-1].to_i > filing_number_limit

      # Void current dormant filing number
      existing_dormant_filing_numbers = PatientIdentifier.where(
        patient: patient, type: dormant_filing_number_identifier_type
      )

      existing_dormant_filing_numbers.each do |identifier|
        identifier.void("Given active filing number: #{filing_number}")
      end

      PatientIdentifier.create patient: patient,
                               type: active_filing_number_identifier_type,
                               identifier: filing_number,
                               location_id: Location.current.location_id
    end
  end

  private

  def filing_number_prefixes
    return @filing_number_prefixes if @filing_number_prefixes

    @filing_number_prefixes = global_property('filing.number.prefix')&.property_value&.split(',')
    @filing_number_prefixes ||= %w[FN101 FN102]
  end

  def filing_number_limit
    @filing_number_limit ||= global_property('filing.number.limit')&.property_value&.to_i || 10_000
  end

  # Build archive candidates from patient list returned by
  # `patients_to_be_archived_based_on_waste_state`
  def build_archive_candidates(patients)
    patients.collect do |patient|
      patient['appointment_date'] = patient_last_appointment(patient[:patient_id])
      patient.update(patient_demographics(patient[:patient_id]))
      patient
    end
  end

  # Return's patient's last appointment date
  def patient_last_appointment(patient_id)
    Observation.where(person_id: patient_id, concept: concept('Appointment date'))\
               .order(:obs_datetime)\
               .last\
               &.obs_datetime
  end

  def patient_demographics(patient_id)
    person_name = PersonName.find_by(person_id: patient_id)
    {
      given_name: person_name&.given_name,
      family_name: person_name&.family_name
    }
  end

  # Source NART/lib/patients_service#get_patient_to_be_archived_based_on_waste_state
  def patients_to_be_archived_based_on_waste_state(offset, limit)
    # The following function will get all transferred out patients
    # with active filling numbers and select one to be archived
    active_filing_number_identifier_type = PatientIdentifierType.find_by_name('Filing Number')

    patient_ids = PatientIdentifier.find_by_sql(
      "SELECT DISTINCT(patient_id) patient_id FROM patient_identifier
      WHERE voided = 0 AND identifier_type = #{active_filing_number_identifier_type.id}
      GROUP BY identifier"
    ).map(&:patient_id)

    duplicate_identifiers = []
    data = PatientIdentifier.find_by_sql(
      "SELECT identifier, count(identifier) AS c
      FROM patient_identifier WHERE voided = 0
      AND identifier_type = #{active_filing_number_identifier_type.id}
      GROUP BY identifier HAVING c > 1"
    )

    (data || []).map do |i|
      duplicate_identifiers << "'#{i['identifier']}'"
    end

    duplicate_identifiers = [] if duplicate_identifiers.blank?

    # here we remove all ids that have any encounter today.
    patient_ids_with_todays_encounters = Encounter.find_by_sql("
      SELECT DISTINCT(patient_id) patient_id FROM encounter
        WHERE voided = 0 AND encounter_datetime BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
              AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
      ").map(&:patient_id)

    filing_number_identifier_type = PatientIdentifierType.find_by_name('Filing number').id

    patient_ids_with_todays_active_filing_numbers = PatientIdentifier.find_by_sql("
      SELECT DISTINCT(patient_id) patient_id FROM patient_identifier
      WHERE voided = 0 AND date_created BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
      AND identifier_type = #{filing_number_identifier_type}").map(&:patient_id)

    patient_ids = (patient_ids - patient_ids_with_todays_encounters)
    patient_ids = (patient_ids - patient_ids_with_todays_active_filing_numbers)
    patient_ids = [0] if patient_ids.blank?

    patient_ids_with_future_app = ActiveRecord::Base.connection.select_all <<-SQL
      SELECT person_id FROM obs
      WHERE concept_id = #{ConceptName.find_by_name('Appointment date').concept_id}
      AND voided = 0 AND value_datetime >= '#{(Date.today - 2.month).strftime('%Y-%m-%d 00:00:00')}'
      GROUP BY person_id;
    SQL

    no_patient_ids = patient_ids_with_future_app.map { |ad| ad['person_id'].to_i }
    no_patient_ids = [0] if patient_ids_with_future_app.blank?

    sql_path = duplicate_identifiers.blank? ? '' : "AND i.identifier NOT IN (#{duplicate_identifiers.join(',')})"

    outcomes = ActiveRecord::Base.connection.select_all <<-SQL
      SELECT
        p.patient_id,  state, start_date, end_date, identifier
      FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN patient_identifier i ON p.patient_id = i.patient_id
        AND i.identifier_type = #{filing_number_identifier_type}
        AND i.voided = 0
      WHERE p.patient_id IN(#{patient_ids.join(',')})
        AND p.patient_id NOT IN (#{no_patient_ids.join(',')})
        #{sql_path}
        AND state IN (2, 3, 4, 5, 6, 8)
          AND state != 7
          AND start_date = (SELECT max(start_date) FROM patient_state t
          WHERE t.patient_program_id = s.patient_program_id)
      GROUP BY p.patient_id ORDER BY state
      LIMIT #{offset}, #{limit};
    SQL

    if outcomes.blank? || (outcomes.length < 5)
      encounter_patient_ids = patients_last_seen_on(150.days.ago)

      encounter_patient_ids = [0] if encounter_patient_ids.blank?

      outcomes = ActiveRecord::Base.connection.select_all <<-SQL
        SELECT p.patient_id, state, start_date, end_date, identifier
        FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN patient_identifier i ON p.patient_id = i.patient_id
        AND i.identifier_type = #{filing_number_identifier_type} AND i.voided = 0
        WHERE p.patient_id IN(#{patient_ids.join(',')})
        AND p.patient_id NOT IN (#{no_patient_ids.join(',')})
        AND start_date = (SELECT max(start_date) FROM patient_state t
            WHERE t.patient_program_id = s.patient_program_id)
        AND p.patient_id IN (#{encounter_patient_ids.join(',')})
        GROUP BY p.patient_id
        ORDER BY state LIMIT #{offset}, #{limit};
      SQL
    end

    processed_states = []
    (outcomes || []).each do |outcome|

      latest_state = ActiveRecord::Base.connection.select_one <<~SQL
       SELECT patient_outcome(#{outcome['patient_id']}, DATE('#{Date.today.to_date}')) state;
      SQL

      processed_states << {
        patient_id: outcome['patient_id'],
        state: latest_state['state'],
        start_date: outcome['start_date'],
        end_date: outcome['end_date'],
        identifier: outcome['identifier']
      }
    end

    return processed_states
  end

  def patients_last_seen_on(date)
    patients = ActiveRecord::Base.connection.select_all <<~SQL
      SELECT DISTINCT patient_program.patient_id
      FROM patient_program
      INNER JOIN patient_identifier
        ON patient_identifier.patient_id = patient_program.patient_id
        AND patient_identifier.voided = 0
      INNER JOIN patient_identifier_type
        ON patient_identifier_type.name = 'Filing number'
        AND patient_identifier_type.retired = 0
        AND patient_identifier_type.patient_identifier_type_id = patient_identifier.identifier_type
      WHERE patient_identifier.voided = 0
        AND patient_program.patient_id NOT IN (
          SELECT DISTINCT patient_id
          FROM encounter
          WHERE encounter_datetime > #{ActiveRecord::Base.connection.quote(date)}
        )
        AND patient_program.program_id = 1
        AND patient_program.voided = 0
    SQL

    patients.collect { |patient| patient['patient_id'] }
  end
end
