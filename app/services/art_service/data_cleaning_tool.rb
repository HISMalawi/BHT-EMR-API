# frozen_string_literal: true

module ARTService
  class DataCleaningTool
    
    TOOLS = {
      'DATE ENROLLED LESS THAN EARLIEST START DATE' => 'date_enrolled_less_than_earliest_start_date',
      'PRE ART OR UNKNOWN OUTCOMES' => 'pre_art_or_unknown_outcomes',
      'MULTIPLE START REASONS' => 'multiple_start_reasons',
      'MISSING START REASONS' => 'missing_start_reasons',
      'PRESCRIPTION WITHOUT DISPENSATION' => 'prescription_without_dispensation',
      'CLIENTS WITH ENCOUNTERS AFTER DECLARED DEAD' => 'client_with_encounters_after_declared_dead',
      'MALE CLIENTS WITH FEMALE OBS' => 'male_clients_with_female_obs',
      'DOB MORE THAN DATE ENROLLED' => 'dob_more_than_date_enrolled'
    }


    def initialize(start_date:, end_date:, tool_name:)
      @start_date = start_date.to_date
      @end_date = end_date.to_date
      @tool_name = tool_name.upcase
    end

    def results
      begin
        return eval(TOOLS["#{@tool_name}"])
      rescue Exception => e
        return "#{e.class}: #{e.message}"
      end
    end

    private

    def dob_more_than_date_enrolled
      data = ActiveRecord::Base.connection.select_all <<EOF
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
        AND i.identifier_type = 4 AND i.voided = 0
        LEFT JOIN person_name n ON n.person_id = pe.person_id AND n.voided = 0
      where
        ((`p`.`voided` = 0)
            and (`s`.`voided` = 0)
            and (`p`.`program_id` = 1)
            and (`s`.`state` = 7))
            and (`s`.`start_date`
            between '#{@start_date.strftime('%Y-%m-%d 00:00:00')}'
            and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}')
      group by `p`.`patient_id`
      HAVING (DATE(date_enrolled) < DATE(birthdate))
      OR (DATE(earliest_start_date) < DATE(birthdate))
      ORDER BY n.date_created DESC;
EOF

      return {} if data.blank?
      return data
    end

    def date_enrolled_less_than_earliest_start_date
      data = ActiveRecord::Base.connection.select_all <<EOF
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
            and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}')
      group by `p`.`patient_id`
      HAVING (date_enrolled IS NOT NULL AND earliest_start_date)
      AND DATE(earliest_start_date) > DATE(date_enrolled);
EOF

      return {} if data.blank?
      patient_ids = data.map{|d| d['patient_id'].to_i}

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate, gender, death_date,
        n.given_name, n.family_name
      FROM person p
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE p.person_id IN(#{patient_ids.join(',')})
      GROUP BY p.person_id ORDER BY i.date_created DESC;
EOF

      return organise_data data
    end

    def pre_art_or_unknown_outcomes
      concept_set_id = concept('Antiretroviral drugs').concept_id
      arvs = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
      where("s.concept_set = ?", concept_set_id).map(&:drug_id)

      data = ActiveRecord::Base.connection.select_all <<EOF
      select
        p.patient_id
      from
        ((`patient_program` `p`
        inner join orders o ON o.patient_id = p.patient_id
        inner join drug_order d ON d.order_id = o.order_id
        and d.drug_inventory_id in(#{arvs.join(',')})
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
            and '#{@end_date.strftime('%Y-%m-%d 23:59:59')}')
      group by `p`.`patient_id` 
      ORDER BY s.start_date DESC;
EOF

      return {} if data.blank?
      patient_ids = []
      data_patient_ids = data.collect{|d| d['patient_id'].to_i}
      
      data_patient_ids.each do |patient_id|
        outcome = ActiveRecord::Base.connection.select_one <<EOF
        SELECT patient_outcome(#{patient_id}, DATE('#{@end_date}')) outcome;
EOF

        if outcome['outcome'].match(/Unknown/i) || outcome['outcome'].match(/Pre/i)
          patient_ids << patient_id
        end
      end

      return {} if patient_ids.blank?

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate, gender, death_date,
        n.given_name, n.family_name
      FROM person p
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE p.person_id IN(#{patient_ids.join(',')})
      GROUP BY p.person_id ORDER BY i.date_created DESC;
EOF

      return organise_data data
    end

    def multiple_start_reasons
      concept_id = concept('Reason for ART eligibility').concept_id

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT person_id, count(concept_id) reason
      FROM obs WHERE concept_id=#{concept_id} AND voided = 0
      GROUP BY person_id HAVING reason > 1;
EOF

      return {} if data.blank?
      patient_ids = data.map{|d| d['person_id'].to_i}

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate, gender, death_date,
        n.given_name, n.family_name
      FROM person p
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE p.person_id IN(#{patient_ids.join(',')})
      GROUP BY p.person_id ORDER BY i.date_created DESC;
EOF

      return organise_data data
    end

    def missing_start_reasons
      concept_set_id = concept('Antiretroviral drugs').concept_id
      arvs = Drug.joins('INNER JOIN concept_set s ON s.concept_id = drug.concept_id').\
      where("s.concept_set = ?", concept_set_id).map(&:drug_id)

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT o.patient_id FROM orders o 
      INNER JOIN drug_order d ON d.order_id = o.order_id AND drug_inventory_id IN(#{arvs.join(',')})
      INNER JOIN encounter e ON e.patient_id = o.patient_id AND e.program_id = 1 AND e.voided = 0
      WHERE d.quantity > 0 AND o.voided = 0 GROUP BY o.patient_id;
EOF

      patient_ids = data.map{ |p| p['patient_id'].to_i }
      return {} if patient_ids.blank?
      concept_id = concept('Reason for ART eligibility').concept_id

      person_ids = Observation.where(concept_id: concept_id, 
        person_id: patient_ids).group(:person_id).map(&:person_id)
      final_list = patient_ids - person_ids
      return {} if final_list.blank?
      
      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate, gender, death_date,
        n.given_name, n.family_name
      FROM person p
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE p.person_id IN(#{final_list.join(',')})
      GROUP BY p.person_id ORDER BY i.date_created DESC;
EOF

      return organise_data data
    end

    def prescription_without_dispensation
      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate,
        gender, start_date, quantity, given_name, family_name
      FROM drug_order t
      INNER JOIN orders o ON o.order_id = t.order_id
      AND start_date BETWEEN '#{@start_date.strftime('%Y-%m-%d 00:00:00')}' 
      AND '#{@end_date.strftime('%Y-%m-%d 23:59:59')}' 
      INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.program_id = 1
      INNER JOIN person p ON p.person_id = o.patient_id
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE o.voided = 0 AND quantity IS NULL OR quantity <= 0
      GROUP BY DATE(start_date), p.person_id ORDER BY i.date_created DESC;
EOF

      client = []
      
      (data || []).each do |person|
        client << {
          arv_number: person['arv_number'],
          given_name: person['given_name'],
          family_name: person['family_name'],
          gender: person['gender'],
          birthdate: person['birthdate'],
          patient_id: person['person_id'],
          start_date: person['start_date']
        }
      end
    
      return client
    end

    def client_with_encounters_after_declared_dead
      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
        p.person_id, i.identifier arv_number, birthdate, 
        gender, death_date, encounter_datetime, given_name,family_name
      FROM person p
      INNER JOIN encounter e ON p.person_id = e.patient_id
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id AND n.voided = 0
      WHERE dead = 1 AND p.voided = 0 AND e.voided = 0
      AND death_date IS NOT NULL AND (DATE(encounter_datetime) > DATE(death_date))
      GROUP BY p.person_id ORDER BY i.date_created DESC;
EOF

      return organise_data data
    end

    def male_clients_with_female_obs
      concept_ids = []
      concept_ids << concept('BREASTFEEDING').concept_id
      concept_ids << concept('BREAST FEEDING').concept_id
      concept_ids << concept('PATIENT PREGNANT').concept_id
      concept_ids << concept('Family planning method').concept_id

      data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT 
        p.person_id, given_name, family_name, gender, birthdate,
        i.identifier arv_number
      FROM person p 
      INNER JOIN obs ON obs.person_id = p.person_id AND (p.gender != 'F' AND p.gender != 'Female') 
      LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
      AND i.identifier_type = 4 AND i.voided = 0
      LEFT JOIN person_name n ON n.person_id = p.person_id
      AND n.voided = 0
      WHERE obs.concept_id IN(#{concept_ids.join(',')}) 
      OR value_coded IN(#{concept_ids.join(',')}) 
      AND p.voided = 0 AND obs.voided = 0 GROUP BY p.person_id
      ORDER BY n.date_created DESC;
EOF

      return organise_data data
    end

    def organise_data(data)
      client = []
      
      (data || []).each do |person|
        client << {
          arv_number: person['arv_number'],
          given_name: person['given_name'],
          family_name: person['family_name'],
          gender: person['gender'],
          birthdate: person['birthdate'],
          patient_id: person['person_id']
        }
      end

      return client
    end



    def concept(name)
      ConceptName.find_by_name(name)
    end

  end
 end
