# rubocop:disable Metrics/MethodLength, Metrics/ClassLength, Style/Documentation, Metrics/AbcSize, Metrics/BlockLength, Security/Eval
# frozen_string_literal: true

module ArtService
  class DataCleaningTool
    include CommonSqlQueryUtils

    TOOLS = {
      'DATE ENROLLED LESS THAN EARLIEST START DATE' => 'date_enrolled_less_than_earliest_start_date',
      'PRE ART OR UNKNOWN OUTCOMES' => 'pre_art_or_unknown_outcomes',
      'MULTIPLE START REASONS' => 'multiple_start_reasons',
      'MISSING START REASONS' => 'missing_start_reasons',
      'PRESCRIPTION WITHOUT DISPENSATION' => 'prescription_without_dispensation',
      'CLIENTS WITH ENCOUNTERS AFTER DECLARED DEAD' => 'client_with_encounters_after_declared_dead',
      'MALE CLIENTS WITH FEMALE OBS' => 'male_clients_with_female_obs',
      'DOB MORE THAN DATE ENROLLED' => 'dob_more_than_date_enrolled',
      'INCOMPLETE VISITS' => 'incomplete_visit',
      'MISSING DEMOGRAPHICS' => 'incomplete_demographics',
      'MISSING VL RESULTS' => 'missing_vl_results',
      'DIFFERENT PREGNANCY VALUE ON SAME DATE' => 'different_pregnancy_value_on_same_date',
      'MISSING ART START DATE' => 'missing_start_date',
      'MULTIPLE OPEN STATES' => 'multiple_open_states'
    }.freeze

    def initialize(start_date:, end_date:, tool_name:)
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @tool_name = tool_name.upcase
    end

    def results
      eval(TOOLS[@tool_name.to_s])
    rescue StandardError => e
      "#{e.class}: #{e.message}"
    end

    def self.void_duplicate_npid(identifier)
      ActiveRecord::Base.connection.execute <<~SQL
        UPDATE patient_identifier
        SET voided = 1,
        void_reason = 'Duplicate identifier: #{identifier}',
        voided_by = #{User.current.id},
        date_voided = current_timestamp()
        WHERE identifier = '#{identifier}'
        AND identifier_type = 3
        AND voided = 0
      SQL
    end

    def missing_start_date
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
        o.person_id AS patient_id,
        p.birthdate,
        p.gender,
        pn.given_name,
        pn.family_name,
        pi.identifier AS arv_number,
        DATE(MIN(o.value_datetime)) value_datetime
        FROM encounter e
        INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
        INNER JOIN person_name pn ON pn.person_id = p.person_id AND pn.voided = 0
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0
          AND o.concept_id = #{concept('Date antiretrovirals started').concept_id}
          AND e.encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE name = 'HIV CLINIC REGISTRATION' LIMIT 1)
          AND e.program_id = (SELECT program_id FROM program WHERE name = 'HIV Program' LIMIT 1)
          AND e.voided = 0
        LEFT JOIN patient_identifier pi ON pi.patient_id = o.person_id
          AND pi.identifier_type = #{indetifier_type} AND pi.voided = 0
          AND o.obs_datetime < #{ActiveRecord::Base.connection.quote(@end_date)}
        WHERE e.voided = 0
        GROUP BY o.person_id, o.value_datetime
        HAVING o.value_datetime IS NULL
      SQL
    end

    def self.void_unknown_identifiers
      ActiveRecord::Base.connection.execute <<~SQL
        UPDATE patient_identifier
        SET voided = 1,
        void_reason = 'Erroneous identifiers',
        voided_by = #{User.current.id},
        date_voided = current_timestamp()
        WHERE LENGTH(identifier) != 6
        AND LENGTH(identifier) != 13
        AND identifier_type = 3
        AND voided = 0
      SQL
    end

    private

    def incomplete_demographics
      data = ActiveRecord::Base.connection.select_all <<~SQL
        select
          `p`.`patient_id` AS `patient_id`, `pe`.`birthdate`,
          n.given_name, n.family_name, pe.gender, i.identifier arv_number
        from
          ((`patient_program` `p`
          left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
          left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
          left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
          LEFT JOIN patient_identifier i ON i.patient_id = pe.person_id
          AND i.identifier_type = #{indetifier_type} AND i.voided = 0
          LEFT JOIN person_name n ON n.person_id = pe.person_id AND n.voided = 0
        where
          ((`p`.`voided` = 0)
              and (`s`.`voided` = 0)
              and (`p`.`program_id` = 1))
              and (`s`.`start_date`
              between '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
              and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}'
              and `p`.`patient_id` NOT IN (#{external_clients}))
        group by `p`.`patient_id`
        HAVING NULLIF(birthdate, '') = NULL OR NULLIF(gender,'') = NULL
        OR NULLIF(given_name,'') = NULL OR NULLIF(family_name,'') = NULL
        ORDER BY n.date_created DESC;
      SQL

      return {} if data.blank?

      data
    end

    def dob_more_than_date_enrolled
      data = ActiveRecord::Base.connection.select_all <<~SQL
        select
          `p`.`patient_id` AS `patient_id`, `pe`.`birthdate`,
          cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
          date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
          n.given_name, n.family_name, pe.gender, i.identifier arv_number
        from
          ((`patient_program` `p`
          left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
          left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
          left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
          LEFT JOIN patient_identifier i ON i.patient_id = pe.person_id
          AND i.identifier_type = #{indetifier_type} AND i.voided = 0
          LEFT JOIN person_name n ON n.person_id = pe.person_id AND n.voided = 0
        where
          ((`p`.`voided` = 0)
              and (`s`.`voided` = 0)
              and (`p`.`program_id` = 1)
              and (`s`.`state` = 7))
              and (`s`.`start_date`
              between '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
              and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}'
              and `p`.`patient_id` NOT IN (#{external_clients}))
        group by `p`.`patient_id`
        HAVING (DATE(date_enrolled) < DATE(birthdate))
        OR (DATE(earliest_start_date) < DATE(birthdate))
        ORDER BY n.date_created DESC;
      SQL

      return {} if data.blank?

      data
    end

    def date_enrolled_less_than_earliest_start_date
      data = ActiveRecord::Base.connection.select_all <<~SQL
        select
          `p`.`patient_id` AS `patient_id`,
          cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
          date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`
        from
          ((`patient_program` `p`
          left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
          left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
          left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
        where
          ((`p`.`voided` = 0)
              and (`s`.`voided` = 0)
              and (`p`.`program_id` = 1)
              and (`s`.`state` = 7))
              and (`s`.`start_date`
              between '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
              and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}'
              and `p`.`patient_id` NOT IN (#{external_clients}))
        group by `p`.`patient_id`
        HAVING (date_enrolled IS NOT NULL AND earliest_start_date)
        AND DATE(earliest_start_date) > DATE(date_enrolled);
      SQL

      return {} if data.blank?

      patient_ids = data.map { |d| d['patient_id'].to_i }

      data = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.person_id, i.identifier arv_number, birthdate, gender, death_date,
          n.given_name, n.family_name
        FROM person p
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
        AND i.identifier_type = #{indetifier_type} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.person_id IN(#{patient_ids.join(',')})
        GROUP BY p.person_id ORDER BY i.date_created DESC;
      SQL

      organise_data data
    end

    def arv_drugs
      Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id')\
          .where('s.concept_set = ?', concept('Antiretroviral drugs').concept_id)\
          .map(&:drug_id)
    end

    def pre_art_or_unknown_outcomes
      data = ActiveRecord::Base.connection.select_all <<~SQL
        select
          p.patient_id
        from
          ((`patient_program` `p`
          inner join orders o ON o.patient_id = p.patient_id
          inner join drug_order d ON d.order_id = o.order_id
          and d.drug_inventory_id in(#{arv_drugs.join(',')})
          left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
          left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
          left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
        where
          ((`p`.`voided` = 0)
              and (`s`.`voided` = 0)
              and (`d`.`quantity` > 0)
              and (`o`.`voided` = 0)
              and (`p`.`program_id` = 1)
              and (`s`.`state` = 7))
              and (`s`.`start_date`
              between '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
              and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}'
              and `p`.`patient_id` NOT IN (#{external_clients}))
        group by `p`.`patient_id`
        ORDER BY s.start_date DESC;
      SQL

      return {} if data.blank?

      patient_ids = []
      data_patient_ids = data.collect { |d| d['patient_id'].to_i }

      data_patient_ids.each do |patient_id|
        outcome = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_outcome(#{patient_id}, DATE('#{@end_date}')) outcome;
        SQL

        patient_ids << patient_id if outcome['outcome'].match(/Unknown/i) || outcome['outcome'].match(/Pre/i)
      end

      return {} if patient_ids.blank?

      data = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.person_id, i.identifier arv_number, birthdate, gender, death_date,
          n.given_name, n.family_name
        FROM person p
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
        AND i.identifier_type = #{indetifier_type} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.person_id IN(#{patient_ids.join(',')})
        GROUP BY p.person_id ORDER BY i.date_created DESC;
      SQL

      organise_data data
    end

    def multiple_start_reasons
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          o.person_id patient_id,
          a.identifier arv_number,
          n.given_name,
          n.family_name,
          p.birthdate,
          p.gender,
          p.death_date,
          GROUP_CONCAT(DISTINCT(vcn.name)) reasons,
          GROUP_CONCAT(DISTINCT(DATE(o.obs_datetime))) visits
        FROM obs o
        INNER JOIN person p ON p.person_id = o.person_id AND p.voided = 0
        INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1 -- HIV Program
        INNER JOIN concept_name cn ON cn.concept_id = o.concept_id AND cn.voided = 0 AND cn.concept_id = #{concept('Reason for ART eligibility').concept_id}
        INNER JOIN concept_name vcn ON vcn.concept_id = o.value_coded AND vcn.voided = 0
        INNER JOIN patient_program pp ON pp.patient_id = o.person_id AND pp.program_id = 1 AND pp.voided = 0
        INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- On ART
        INNER JOIN (
          SELECT pp.patient_id, MIN(start_date) AS start_date
          FROM patient_program pp
          INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- On ART
          WHERE pp.voided = 0 AND pp.program_id = 1 -- HIV Program
          GROUP BY pp.patient_id
        ) AS ms ON ms.patient_id = pp.patient_id AND ms.start_date = ps.start_date AND o.obs_datetime > ps.start_date
        LEFT JOIN patient_identifier a ON a.patient_id = pp.patient_id AND a.voided = 0 AND a.identifier_type = #{indetifier_type}
        LEFT JOIN person_name n ON n.person_id = pp.patient_id AND n.voided = 0
        WHERE o.voided = 0
        AND o.person_id NOT IN (#{external_clients})
        GROUP BY o.person_id HAVING COUNT(DISTINCT(o.value_coded)) > 1 OR COUNT(DISTINCT(DATE(o.obs_datetime))) > 1;
      SQL
    end

    def missing_start_reasons
      start_date = ActiveRecord::Base.connection.quote(@start_date.to_date)
      end_date = ActiveRecord::Base.connection.quote(@end_date.to_date)

      clients = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT patient_program.patient_id,
               reason_for_art_eligibility.value_coded AS reason_for_art,
               MIN(orders.start_date) AS art_start_date
        FROM patient_program
        INNER JOIN program
          ON program.program_id = patient_program.program_id
          AND program.name = 'HIV Program'
        INNER JOIN orders
          ON orders.patient_id = patient_program.patient_id
          AND orders.start_date < #{end_date}
          AND orders.voided = 0
          AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
          AND orders.concept_id IN (
            SELECT concept_set.concept_id
            FROM concept_set
            INNER JOIN concept_name
              ON concept_name.concept_id = concept_set.concept_set
              AND concept_name.name = 'Antiretroviral drugs'
          )
        INNER JOIN obs AS amount_dispensed
          ON amount_dispensed.order_id = orders.order_id
          AND amount_dispensed.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Amount dispensed' AND voided = 0)
          AND amount_dispensed.value_numeric > 0
          AND amount_dispensed.voided = 0
        LEFT JOIN obs AS reason_for_art_eligibility
          ON reason_for_art_eligibility.person_id = patient_program.patient_id
          AND reason_for_art_eligibility.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' AND voided = 0)
          AND reason_for_art_eligibility.voided = 0
        WHERE patient_program.patient_id NOT IN (#{external_clients})
        GROUP BY patient_program.patient_id
        HAVING reason_for_art IS NULL AND art_start_date >= DATE(#{start_date})
      SQL

      patient_ids = clients.map { |p| p['patient_id'].to_i }
      return {} if patient_ids.blank?

      data = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          p.person_id, i.identifier arv_number, birthdate, gender, death_date,
          n.given_name, n.family_name
        FROM person p
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
        AND i.identifier_type = #{indetifier_type} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.person_id IN(#{patient_ids.join(',')})
        GROUP BY p.person_id ORDER BY i.date_created DESC;
      SQL

      organise_data data
    end

    def prescription_without_dispensation
      start_date = ActiveRecord::Base.connection.quote(@start_date.strftime('%Y-%m-%d 00:00:00'))
      end_date = ActiveRecord::Base.connection.quote(@end_date.strftime('%Y-%m-%d 23:59:59'))

      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT orders.patient_id,
               patient_identifier.identifier AS arv_number,
               birthdate,
               gender,
               start_date AS visit_date,
               quantity,
               given_name,
               family_name
        FROM drug_order
        INNER JOIN orders
          ON orders.order_id = drug_order.order_id
          AND orders.start_date BETWEEN #{start_date} AND #{end_date}
          AND orders.voided = 0
        INNER JOIN encounter
          ON encounter.encounter_id = orders.encounter_id
          AND encounter.program_id = 1
        INNER JOIN person
          ON person.person_id = orders.patient_id
        LEFT JOIN patient_identifier
          ON patient_identifier.patient_id = person.person_id
          AND patient_identifier.identifier_type = #{indetifier_type}
          AND patient_identifier.voided = 0
        LEFT JOIN person_name
          ON person_name.person_id = person.person_id
          AND person_name.voided = 0
        LEFT JOIN obs AS dispensation
          ON dispensation.order_id = orders.order_id
          AND dispensation.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Amount Dispensed' AND voided = 0)
          AND dispensation.voided = 0
        WHERE drug_order.drug_inventory_id IN (#{arv_drugs.join(',')})
        AND (drug_order.quantity IS NULL OR drug_order.quantity <= 0 AND orders.patient_id NOT IN(#{external_clients}))
        GROUP BY DATE(orders.start_date), orders.patient_id
        HAVING COALESCE(SUM(dispensation.value_numeric), 0) <= 0
      SQL
    end

    def client_with_encounters_after_declared_dead
      data = ActiveRecord::Base.connection.select_all <<~SQL
        SELECT person.person_id,
               patient_identifier.identifier AS arv_number,
               person.birthdate,
               person.gender,
               deaths.death_date,
               encounter.encounter_datetime,
               person_name.given_name,
               person_name.family_name
        FROM (
          /* Recorded deaths */
          SELECT patient_program.patient_program_id,
                 patient_program.patient_id,
                 patient_state.start_date AS death_date
          FROM patient_program
          INNER JOIN patient_state
            ON patient_state.patient_program_id = patient_program.patient_program_id
            AND patient_state.voided = 0
            AND patient_state.state IN (
              /* State: Patient Died */
              SELECT program_workflow_state.program_workflow_state_id
              FROM program_workflow_state
              INNER JOIN program_workflow
                ON program_workflow.program_workflow_id = program_workflow_state.program_workflow_id
                AND program_workflow.program_id = 1
                AND program_workflow.retired = 0
              INNER JOIN concept_name
                ON concept_name.concept_id = program_workflow_state.concept_id
                AND concept_name.name = 'Patient Died'
                AND concept_name.voided = 0
              WHERE program_workflow_state.retired = 0
            )
          WHERE patient_program.program_id = 1
            AND patient_program.voided = 0
        ) AS deaths
        INNER JOIN encounter
          /* Need ART encounters only that come after the recorded death above. */
          ON encounter.patient_id = deaths.patient_id
          AND encounter.encounter_datetime >= DATE(deaths.death_date) + INTERVAL 1 DAY
          AND encounter.program_id = 1
          AND encounter.encounter_type NOT IN (
            SELECT encounter_type_id FROM encounter_type WHERE name = 'HIV Reception' OR name LIKE '%lab%'
          )
          AND encounter.voided = 0
        INNER JOIN person
          ON person.person_id = deaths.patient_id
        LEFT JOIN patient_identifier
          ON patient_identifier.patient_id = deaths.patient_id
          AND patient_identifier.voided = 0
          AND patient_identifier.identifier_type = #{indetifier_type}
        LEFT JOIN person_name
          ON person_name.person_id = deaths.patient_id
          AND person_name.voided = 0
        WHERE person.person_id NOT IN(#{external_clients})
        GROUP BY deaths.patient_id
        ORDER BY patient_identifier.date_created DESC
      SQL

      organise_data(data)
    end

    def male_clients_with_female_obs
      concept_ids = []
      concept_ids << concept('BREASTFEEDING').concept_id
      concept_ids << concept('BREAST FEEDING').concept_id
      concept_ids << concept('PATIENT PREGNANT').concept_id
      concept_ids << concept('Family planning method').concept_id

      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT p.person_id patient_id, given_name, family_name, gender, birthdate,
               i.identifier arv_number, GROUP_CONCAT(DISTINCT(DATE(obs.obs_datetime))) visit_date
        FROM person p
        INNER JOIN obs o ON o.person_id = p.person AND (o.concept_id IN(#{concept_ids.join(',')}) OR o.value_coded IN(#{concept_ids.join(',')})) AND o.voided = 0
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id AND i.identifier_type = #{indetifier_type} AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        WHERE p.voided = 0 AND p.person_id NOT IN(#{external_clients})
        GROUP BY p.person_id
        ORDER BY n.date_created DESC;
      SQL
    end

    def organise_data(data)
      client = []

      (data || []).each do |person|
        record = {
          arv_number: person['arv_number'],
          given_name: person['given_name'],
          family_name: person['family_name'],
          gender: person['gender'],
          birthdate: person['birthdate'],
          patient_id: person['person_id']
        }

        record['visit_date'] = person['visit_date'].to_date.strftime('%d-%b-%Y') if person['visit_date'].present?

        client << record
      end

      client
    end

    def incomplete_visit
      patient_visit_dates = patient_visits.map { |visit| [visit['patient_id'], visit['visit_date']] }

      return {} if patient_visit_dates.blank?

      incomplete_visits_comp = {}

      patient_visit_dates.each do |patient_id, visit_date|
        patient = Patient.find(patient_id)
        date =  visit_date.to_date
        workflow_engine = ArtService::WorkflowEngine.new(patient:, date:, program:)
        complete = workflow_engine.next_encounter.blank? ? true : false

        next if complete

        person_details = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT
            n.given_name, n.family_name, p.gender, p.birthdate,
            a.identifier arv_number, i.identifier national_id
          FROM person p
          LEFT JOIN patient_identifier a ON a.patient_id = p.person_id
          AND a.identifier_type = #{indetifier_type} AND a.voided = 0
          LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
          AND i.identifier_type = 3 AND i.voided = 0
          LEFT JOIN person_name n On n.person_id = p.person_id AND n.voided = 0
          WHERE p.person_id = #{patient_id} AND p.voided = 0
          GROUP BY p.person_id ORDER BY i.date_created DESC,
          a.date_created DESC, n.date_created DESC;
        SQL

        if incomplete_visits_comp[patient_id].blank?
          incomplete_visits_comp[patient_id] = {
            given_name: person_details['given_name'],
            family_name: person_details['family_name'],
            gender: person_details['gender'],
            birthdate: person_details['birthdate'],
            arv_number: person_details['arv_number'],
            national_id: person_details['national_id'],
            dates: []
          }
        end
        incomplete_visits_comp[patient_id][:dates] << visit_date.to_date
      end

      incomplete_visits_comp
    end

    def missing_vl_results
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT o.order_id, n.given_name, n.family_name, p.gender, p.birthdate, a.identifier arv_number,
        i.identifier national_id, ord.accession_number, DATE(ord.start_date) order_date, p.person_id patient_id
        FROM obs o
        INNER JOIN orders ord ON ord.order_id = o.order_id AND ord.voided = 0
        INNER JOIN person p ON p.person_id = o.person_id AND p.voided = 0
        INNER JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        LEFT JOIN patient_identifier a ON a.patient_id = p.person_id AND a.voided = 0 AND a.identifier_type = #{indetifier_type}
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id AND i.voided = 0 AND i.identifier_type = 3
        LEFT JOIN obs tr ON tr.obs_group_id = o.obs_id AND tr.voided = 0 AND tr.concept_id = #{concept('Lab test result').concept_id}
        LEFT JOIN obs r ON r.obs_group_id = tr.obs_id AND r.voided = 0 AND r.concept_id = #{concept('HIV viral load').concept_id}
        AND r.value_modifier IS NOT NULL and (r.value_numeric IS NOT NULL OR r.value_text IS NOT NULL)
        WHERE o.concept_id = #{concept('Test type').concept_id} AND o.value_coded = #{concept('HIV viral load').concept_id} AND o.voided = 0
        AND o.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
        AND tr.obs_id IS NULL AND r.obs_id IS NULL
      SQL
    end

    def different_pregnancy_value_on_same_date
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT
          person.person_id patient_id,
          person_name.given_name,
          person_name.family_name,
          DATE(obs1.obs_datetime) AS visit_date,
          person.gender,
          person.birthdate,
          a.identifier arv_number,
          i.identifier national_id
        FROM
          obs AS obs1
        INNER JOIN
          obs AS obs2 ON obs1.person_id = obs2.person_id
                      AND obs1.concept_id = obs2.concept_id
                      AND DATE(obs1.obs_datetime) = DATE(obs2.obs_datetime)
                      AND obs1.obs_id < obs2.obs_id
                      AND obs2.voided = 0
                      AND obs2.concept_id = #{concept('Is patient pregnant?').concept_id}
                      AND obs2.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
        INNER JOIN person ON person.person_id = obs1.person_id AND person.voided = 0
        INNER JOIN person_name ON person_name.person_id = person.person_id AND person_name.voided = 0
        LEFT JOIN patient_identifier a ON a.patient_id = person.person_id AND a.voided = 0 AND a.identifier_type = #{indetifier_type}
        LEFT JOIN patient_identifier i ON i.patient_id = person.person_id AND i.voided = 0 AND i.identifier_type = 3
        WHERE
          obs1.concept_id = #{concept('Is patient pregnant?').concept_id}
          AND obs1.voided = 0
          AND obs1.value_coded <> obs2.value_coded
          AND obs1.obs_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
        GROUP BY person.person_id
      SQL
    end

    def multiple_open_states
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT p.person_id patient_id, n.given_name,n.family_name, p.gender,p.birthdate,a.identifier arv_number, i.identifier national_id,
        ps.start_date, GROUP_CONCAT(DISTINCT(cn.name)) states, COUNT(DISTINCT(ps.state)) state_count
        FROM patient_state ps
        INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.voided = 0 AND pp.program_id = 1 -- HIV Program
        INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
        INNER JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
        INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state AND pws.retired = 0
        INNER JOIN concept_name cn ON cn.concept_id = pws.concept_id AND cn.voided = 0 AND cn.concept_name_type = 'FULLY_SPECIFIED'
        LEFT JOIN patient_identifier a ON a.patient_id = p.person_id AND a.voided = 0 AND a.identifier_type = #{indetifier_type}
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id AND i.voided = 0 AND i.identifier_type = 3
        WHERE ps.voided = 0 AND ps.start_date BETWEEN '#{@start_date}' AND '#{@end_date}' AND (ps.end_date IS NULL OR ps.end_date > '#{@end_date}')
        AND p.person_id NOT IN(#{external_clients})
        GROUP BY p.person_id, ps.start_date HAVING state_count > 1;
      SQL
    end

    def concept(name)
      ConceptName.find_by_name(name)
    end

    def program
      @program ||= Program.find_by_name!('HIV Program')
    end

    def indetifier_type
      @indetifier_type ||= PatientIdentifierType\
                           .find_by_name!(GlobalPropertyService.use_filing_numbers? ? 'Filing Number' : 'ARV Number').id
    end

    ##
    # Returns all non-refill (external consultation) visits patients have had in a given time period
    def patient_visits
      ActiveRecord::Base.connection.select_all <<~SQL
        SELECT encounter.patient_id, DATE(encounter.encounter_datetime) AS visit_date
        FROM encounter
        INNER JOIN (
            SELECT patient_id, MAX(encounter_datetime) AS encounter_datetime
            FROM encounter
            WHERE encounter_type = #{EncounterType.find_by_name!('Registration').encounter_type_id}
              AND encounter_datetime <= DATE(#{ActiveRecord::Base.connection.quote(@end_date)}) + INTERVAL 1 DAY
              AND voided = 0
            GROUP BY patient_id
        ) AS max_registration_encounter
          ON max_registration_encounter.encounter_datetime <= encounter.encounter_datetime
          AND max_registration_encounter.patient_id = encounter.patient_id
        WHERE encounter.encounter_datetime >= DATE(#{ActiveRecord::Base.connection.quote(@start_date)})
          AND encounter.encounter_datetime < DATE(#{ActiveRecord::Base.connection.quote(@end_date)}) + INTERVAL 1 DAY
          AND encounter.encounter_type NOT IN (
            SELECT encounter_type_id FROM encounter_type WHERE name IN ('EXIT FROM HIV CARE', 'LAB', 'LAB ORDERS', 'LAB RESULTS')
          )
          AND program_id = #{Program.find_by_name!('HIV Program').program_id}
          AND voided = 0
        GROUP BY encounter.patient_id, DATE(encounter.encounter_datetime)
      SQL
    end

    # Method to fetch all external and drug refills from the system
    def external_clients
      property = GlobalProperty.find_by(property: 'can.remove.external.and.drug.refills.from.data.cleaning')
      return 0 if property.blank? || property&.property_value == 'false'

      clients = ActiveRecord::Base.connection.select_all external_client_query(end_date: @end_date.to_date)
      clients.map { |record| record['person_id'] }.push(0).join(',')
    end
  end
end

# rubocop:enable Metrics/MethodLength, Metrics/ClassLength, Style/Documentation, Metrics/AbcSize, Metrics/BlockLength, Security/Eval
