# frozen_string_literal: true

class FilingNumberService
  attr_reader :date

  include ModelUtils

  def initialize(date: nil)
    @date = date&.to_date || Date.today
  end

  # Find patients that have an active filing number that are eligible for archiving.
  #
  # Search order is as follows:
  #   1. Patients with outcome 'Patient died'
  #   2. Patients with outcome 'Patient transferred out'
  #   3. Patients with outcome 'Treatment stopped'
  #   4. Patients with outcome 'Defaulted'
  def find_archiving_candidates(offset = nil, limit = nil)
    offset ||= 0
    limit ||= 12
    remove_temp_tables
    create_temp_index_on_orders_table
    create_temp_potential_filing_number_candidates
    create_temp_patient_with_adverse_outcomes
    # patients = find_active_patients_with_adverse_outcomes
    # return build_archive_candidates(patients) unless patients.empty?

    # build_archive_candidates(find_potential_defaulters)
    result = (find_patient_with_adverse_outcomes(offset, limit / 2).to_a + find_defaulters(offset, limit / 2).to_a).sort_by { |k| k['start_date'] }
    build_archive_candidates(result)
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
    return find_lost_active_filing_number if type.match?(/^Filing.*/i) && next_id > filing_number_limit

    if next_id > PHYSICAL_FILING_NUMBER_LIMIT
      raise "At physical filing number limit: #{next_id} > #{PHYSICAL_FILING_NUMBER_LIMIT}"
    end

    prefix + next_id.to_s.rjust(5, '0')
  end

  ##
  # Looks for previously assigned active filing number that was voided and wasn't assigned to
  # anyone else.
  def find_lost_active_filing_number
    prefix = filing_number_prefixes[0]
    filing_number_type = patient_identifier_type('Filing number').id

    identifier = ActiveRecord::Base.connection.select_one <<~SQL
      SELECT DISTINCT identifier
      FROM patient_identifier
      WHERE identifier_type = #{ActiveRecord::Base.connection.quote(filing_number_type)}
        AND identifier LIKE #{ActiveRecord::Base.connection.quote("#{prefix}%")}
        AND voided = 1
        AND identifier < #{ActiveRecord::Base.connection.quote(prefix + filing_number_limit.to_s)}
        AND identifier NOT IN (
          SELECT identifier
          FROM patient_identifier
          WHERE voided = 0
            AND identifier_type = #{ActiveRecord::Base.connection.quote(filing_number_type)}
            AND identifier LIKE #{ActiveRecord::Base.connection.quote("#{prefix}%")}
        )
    SQL

    identifier&.fetch('identifier', nil)
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
    return [] if patients.empty?

    demographics_list = find_patients_demographics_and_appointment(patients.collect do |patient|
                                                                     patient['patient_id']
                                                                   end).to_a

    patients.each do |patient|
      patient_demographics = demographics_list.bsearch do |demographics|
        demographics['patient_id'] >= patient['patient_id']
      end

      patient['appointment_date'] = patient_demographics&.fetch('appointment_date')
      patient['given_name'] = patient_demographics&.fetch('given_name')
      patient['family_name'] = patient_demographics&.fetch('family_name')
      patient['birthdate'] = patient_demographics&.fetch('birthdate')
      patient['gender'] = patient_demographics&.fetch('gender')
      patient['state'] = patient_demographics&.fetch('outcome') || patient['state']
    end

    patients
  end

  # Return's patient's last appointment date
  def find_patients_demographics_and_appointment(patient_ids)
    patient_ids = patient_ids.map { |patient_id| ActiveRecord::Base.connection.quote(patient_id) }.join(',')

    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT person.person_id AS patient_id,
             person.birthdate,
             person.gender,
             person_name.given_name,
             person_name.family_name,
             MAX(obs.value_datetime) AS appointment_date,
             patient_outcome(person.person_id, DATE(#{ActiveRecord::Base.connection.quote(date)})) AS outcome
      FROM person
      INNER JOIN person_name ON person_name.person_id = person.person_id AND person_name.voided = 0
      LEFT JOIN obs
        ON obs.person_id = person.person_id
        AND obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Appointment date')
        AND obs.value_datetime < DATE(#{ActiveRecord::Base.connection.quote(date)}) + INTERVAL 1 DAY
        AND obs.encounter_id IN (
          SELECT encounter_id
          FROM encounter
          WHERE encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Appointment')
            AND patient_id IN (#{patient_ids})
            AND encounter_datetime < DATE(#{ActiveRecord::Base.connection.quote(date)}) + INTERVAL 1 DAY
            AND voided = 0
        )
        AND obs.voided = 0
      WHERE person.voided = 0 AND person.person_id IN (#{patient_ids})
      GROUP BY person.person_id
      ORDER BY person.person_id ASC
    SQL
  end

  # def find_active_patients_with_adverse_outcomes
  #   ActiveRecord::Base.connection.select_all <<~SQL
  #     SELECT filing_numbers.patient_id,
  #            filing_numbers.identifier AS filing_number,
  #            patient_state.start_date AS start_date,
  #            patient_state.end_date AS end_date,
  #            concept_name.name AS state,
  #            filing_numbers.date_created AS date_activated
  #     FROM (
  #       /* Unique active filing numbers */
  #       SELECT patient_id, identifier, date_created
  #       FROM patient_identifier
  #       WHERE voided = 0
  #         AND identifier_type = #{ActiveRecord::Base.connection.quote(filing_number_type.id)}
  #         AND date_created < DATE(#{ActiveRecord::Base.connection.quote(date)})
  #       GROUP BY identifier
  #       HAVING COUNT(*) = 1
  #     ) AS filing_numbers
  #     /* Ensure latest outcome for each patient is adverse */
  #     INNER JOIN patient_program
  #       ON patient_program.patient_id = filing_numbers.patient_id
  #       AND patient_program.program_id = #{ActiveRecord::Base.connection.quote(hiv_program.program_id)}
  #       AND patient_program.voided = 0
  #     INNER JOIN patient_state
  #       ON patient_state.patient_program_id = patient_program.patient_program_id
  #       AND patient_state.state IN (#{adverse_outcomes.to_sql})
  #       AND patient_state.voided = 0
  #     INNER JOIN (
  #       SELECT patient_program_id, MAX(start_date) AS start_date
  #       FROM patient_state
  #       INNER JOIN patient_program USING (patient_program_id)
  #       WHERE patient_state.voided = 0
  #         AND patient_state.start_date < DATE(#{ActiveRecord::Base.connection.quote(date)}) /* Avoid patients who started today */
  #         AND patient_program.voided = 0
  #         AND patient_program.program_id = #{ActiveRecord::Base.connection.quote(hiv_program.program_id)}
  #       GROUP BY patient_program_id
  #     ) AS latest_outcome
  #       ON latest_outcome.patient_program_id = patient_state.patient_program_id
  #       AND latest_outcome.start_date = patient_state.start_date
  #     /* Need the following for the outcome's name */
  #     INNER JOIN program_workflow_state
  #       ON program_workflow_state.program_workflow_state_id = patient_state.state
  #     INNER JOIN concept_name
  #       ON concept_name.concept_id = program_workflow_state.concept_id
  #     WHERE filing_numbers.patient_id NOT IN (
  #       /* patients with pending future visits (appointments) */
  #       SELECT obs.person_id
  #       FROM obs
  #       INNER JOIN encounter
  #         ON encounter.encounter_id = obs.encounter_id
  #         AND encounter.program_id = #{ActiveRecord::Base.connection.quote(hiv_program.program_id)}
  #         AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name LIKE 'Appointment')
  #         AND encounter.voided = 0
  #       WHERE obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name LIKE 'Appointment date' AND voided = 0)
  #         AND obs.value_datetime >= DATE(#{ActiveRecord::Base.connection.quote(date)})
  #         AND obs.voided = 0
  #     )
  #     GROUP BY filing_numbers.patient_id
  #     ORDER BY filing_numbers.date_created ASC, patient_state.start_date ASC, filing_numbers.identifier ASC
  #     LIMIT 144 /* Should be enough for a clinician to make a decision */
  #   SQL
  # end

  # def find_potential_defaulters
  #   ActiveRecord::Base.connection.select_all <<~SQL
  #     SELECT filing_numbers.patient_identifier_id,
  #            filing_numbers.patient_id,
  #            filing_numbers.identifier AS filing_number,
  #            MAX(orders.auto_expire_date) AS start_date,
  #            NULL AS end_date,
  #            /* patient_outcome(filing_numbers.patient_id, DATE(#{ActiveRecord::Base.connection.quote(date)})) AS state, */
  #            'Potential defaulter' AS state, /* Operation above slows down things a lot */
  #            filing_numbers.date_created AS date_activated
  #     /* Grab unique active filing numbers */
  #     FROM (
  #       SELECT patient_identifier_id, patient_identifier.patient_id, identifier, date_created
  #       FROM patient_identifier
  #       LEFT JOIN (
  #         /* Definitely not defaulters */
  #         SELECT orders.patient_id
  #         FROM orders
  #         INNER JOIN order_type
  #           ON order_type.order_type_id = orders.order_type_id
  #           AND order_type.name = 'Drug order'
  #         INNER JOIN drug_order ON drug_order.order_id = orders.order_id AND quantity > 0
  #         WHERE orders.concept_id IN (#{antiretroviral_drug_concepts.join(',')})
  #           AND orders.auto_expire_date > DATE(#{ActiveRecord::Base.connection.quote(date)}) - INTERVAL 28 DAY
  #           AND orders.voided = 0
  #         UNION
  #         SELECT obs.person_id
  #         FROM obs
  #         INNER JOIN concept_name
  #           ON concept_name.concept_id = obs.concept_id
  #           AND concept_name.name = 'Appointment date'
  #           AND concept_name.voided = 0
  #         INNER JOIN encounter
  #           ON encounter.encounter_id = obs.encounter_id
  #           AND encounter.program_id = #{hiv_program.program_id}
  #           AND encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Appointment')
  #           AND encounter.voided = 0
  #         WHERE obs.voided = 0
  #           AND obs.value_datetime >= DATE(#{ActiveRecord::Base.connection.quote(date)})
  #       ) AS non_defaulters
  #         ON non_defaulters.patient_id = patient_identifier.patient_id
  #       WHERE non_defaulters.patient_id IS NULL /* Remove obvious defaulters */
  #         AND patient_identifier.patient_id IS NOT NULL
  #         AND voided = 0
  #         AND identifier_type = #{ActiveRecord::Base.connection.quote(filing_number_type.id)}
  #         AND date_created < DATE(#{ActiveRecord::Base.connection.quote(date)})
  #       GROUP BY identifier
  #       HAVING COUNT(*) = 1
  #     ) AS filing_numbers
  #     /* Find patients who have gone more than 28 days without visiting since their last order */
  #     INNER JOIN orders
  #       ON orders.patient_id = filing_numbers.patient_id
  #       AND orders.concept_id IN (#{antiretroviral_drug_concepts.join(',')})
  #       AND orders.auto_expire_date <= DATE(#{ActiveRecord::Base.connection.quote(date)}) - INTERVAL 28 DAY
  #       AND orders.voided = 0
  #     INNER JOIN order_type
  #       ON order_type.order_type_id = orders.order_type_id
  #       AND order_type.name = 'Drug order'
  #     INNER JOIN drug_order
  #       ON drug_order.order_id = orders.order_id
  #       AND drug_order.quantity > 0
  #     GROUP BY filing_numbers.patient_id
  #     ORDER BY orders.auto_expire_date ASC, filing_numbers.date_created ASC, filing_numbers.identifier ASC
  #     LIMIT 144
  #   SQL
  # end

  def find_patient_with_adverse_outcomes(offset, limit)
    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT
        fn.patient_identifier_id,
        fn.identifier,
        fn.patient_id,
        adverse.name AS state,
        adverse.start_date AS start_date,
        adverse.end_date AS end_date,
        fn.date_created AS date_activated
      FROM temp_potential_filing_number_candidates fn
      INNER JOIN temp_patient_with_adverse_outcomes adverse
        ON adverse.patient_id = fn.patient_id
      ORDER BY adverse.start_date ASC
      LIMIT #{offset},#{limit}
    SQL
  end

  def find_defaulters(offset, limit)
    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT
        pi.patient_identifier_id,
        pi.identifier,
        orders_view.patient_id,
        'Defaulted' AS state,
        orders_view.start_date,
        NULL AS end_date,
        pi.date_created date_activated
      FROM (
        SELECT o.patient_id, MAX(o.auto_expire_date) start_date
        FROM orders o
        WHERE o.voided = 0
          AND o.concept_id IN (#{antiretroviral_drug_concepts.join(',')})
        GROUP BY o.patient_id
      ) orders_view
      INNER JOIN temp_potential_filing_number_candidates pi
        ON pi.patient_id = orders_view.patient_id
      WHERE orders_view.start_date <= DATE(#{ActiveRecord::Base.connection.quote(date)}) - INTERVAL 240 DAY
        AND orders_view.patient_id NOT IN (SELECT patient_id FROM temp_patient_with_adverse_outcomes)
      ORDER BY orders_view.start_date ASC
      LIMIT #{offset},#{limit}
    SQL
  end

  def create_temp_patient_with_adverse_outcomes
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TEMPORARY TABLE temp_patient_with_adverse_outcomes (
        patient_id int NOT NULL,
        patient_program_id int NOT NULL,
        state int NOT NULL,
        start_date varchar(50),
        end_date varchar(50),
        name varchar(50),
        PRIMARY KEY (patient_program_id),
        INDEX (patient_id)
      )
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_patient_with_adverse_outcomes
      SELECT p.patient_id, n.*
      FROM patient_program p
      INNER JOIN (
        SELECT ps.patient_program_id, ps.state, ps.start_date, ps.end_date, cn.name
        FROM patient_state ps
        INNER JOIN program_workflow_state ws
          ON ps.state = ws.program_workflow_state_id
          AND ws.retired = 0
        INNER JOIN concept_name cn
          ON cn.concept_id = ws.concept_id
          AND cn.voided = 0
        INNER JOIN(
          SELECT pis.patient_program_id, MAX(pis.start_date) start_date
          FROM patient_state pis
          WHERE pis.voided = 0
          GROUP BY pis.patient_program_id
        ) pis
          ON pis.patient_program_id = ps.patient_program_id
          AND pis.start_date = ps.start_date
          AND ps.end_date IS NULL
        GROUP BY ps.patient_program_id
        HAVING count(ps.state) = 1
      ) n
        ON n.patient_program_id = p.patient_program_id
      WHERE p.program_id = #{hiv_program.program_id}
        AND p.voided = 0
        AND n.state IN (#{adverse_outcomes.to_sql})
    SQL
  end

  def create_temp_index_on_orders_table
    return if ActiveRecord::Base.connection.index_exists?(:orders, %i[concept_id])

    ActiveRecord::Base.connection.execute <<~SQL
      ALTER TABLE orders add index idx_orders_concept_id (concept_id)
    SQL
  end

  def create_temp_potential_filing_number_candidates
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TEMPORARY TABLE temp_potential_filing_number_candidates(
        identifier varchar(50) NOT NULL,
        patient_id int NOT NULL,
        patient_identifier_id INT NOT NULL,
        date_created VARCHAR(50) NOT NULL,
        PRIMARY KEY (identifier),
        INDEX (patient_id)
      )
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      INSERT INTO temp_potential_filing_number_candidates
      SELECT identifier,patient_id,patient_identifier_id,date_created
      FROM patient_identifier
      WHERE identifier_type = #{ActiveRecord::Base.connection.quote(filing_number_type.id)}
      AND voided = 0
      GROUP BY identifier
      HAVING COUNT(*) = 1
    SQL
  end

  def adverse_outcomes
    ProgramWorkflowState.joins(:program_workflow)
                        .where(initial: 0, terminal: 1,
                               program_workflow: { program_id: Program.where(name: 'HIV Program') })
                        .select(:program_workflow_state_id)
  end

  def remove_temp_tables
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TEMPORARY TABLE IF EXISTS temp_patient_with_adverse_outcomes
    SQL
    ActiveRecord::Base.connection.execute <<~SQL
      DROP TEMPORARY TABLE IF EXISTS temp_potential_filing_number_candidates
    SQL
  end

  # ADVERSE_OUTCOME_NAMES = [
  #   'z_deprecated Treatment stopped - provider initiated',
  #   'z_deprecated Treatment stopped - patient refused',
  #   'Patient died',
  #   'Patient transferred out',
  #   'Treatment never started',
  #   'Treatment stopped'
  # ].freeze

  # def adverse_outcomes
  #   ProgramWorkflowState.joins(:program_workflow)
  #                       .joins('INNER JOIN concept_name ON concept_name.concept_id = program_workflow_state.concept_id')
  #                       .where(concept_name: { name: ADVERSE_OUTCOME_NAMES, voided: 0 },
  #                              program_workflow: { program_id: Program.where(name: 'HIV Program').select(:program_id) })
  #                       .select(:program_workflow_state_id)
  # end

  def hiv_program
    @hiv_program ||= Program.find_by!(name: 'HIV Program')
  end

  def filing_number_type
    @filing_number_type ||= PatientIdentifierType.find_by!(name: 'Filing number')
  end

  def antiretroviral_drug_concepts
    @antiretroviral_drug_concepts ||= ConceptSet.find_members_by_name('Antiretroviral drugs').select(:concept_id).collect(&:concept_id)
  end
end
