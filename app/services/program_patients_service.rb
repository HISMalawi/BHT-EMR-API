class ProgramPatientsService
  ENGINES = {
    'HIV PROGRAM' => ARTService::PatientsEngine,
    'TB PROGRAM' => TBService::PatientsEngine
  }.freeze

  def initialize(program:)
    clazz = ENGINES[program.concept.concept_names[0].name.upcase]
    @engine = clazz.new(program: program)
  end

  def method_missing(method, *args, &block)
    Rails.logger.debug "Executing missing method: #{method}"
    return @engine.send(method, *args, &block) if respond_to_missing?(method)

    super(method, *args, &block)
  end

  def respond_to_missing?(method)
    Rails.logger.debug "Engine responds to #{method}? #{@engine.respond_to?(method)}"
    @engine.respond_to?(method)
  end

  def defaulter_list(start_date, end_date)
#=begin 
    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `temp_earliest_start_date`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE temp_earliest_start_date
        select
            `p`.`patient_id` AS `patient_id`,
            `pe`.`gender` AS `gender`,
            `pe`.`birthdate`,
            date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
            cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
            `person`.`death_date` AS `death_date`,
            (select timestampdiff(year, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_at_initiation`,
            (select timestampdiff(day, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_in_days`
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
        group by `p`.`patient_id`;
EOF
#=end

    data = ActiveRecord::Base.connection.select_all("SELECT e.patient_id, 
    patient_outcome(e.patient_id, DATE('#{end_date}')) outcome, 
    current_defaulter_date(e.patient_id, DATE('#{end_date}')) outcome_date
    FROM temp_earliest_start_date e WHERE date_enrolled BETWEEN '#{start_date.strftime('%Y-%m-%d')}'
    AND '#{end_date.strftime('%Y-%m-%d')}' HAVING outcome LIKE '%defau%';")
 
    patient_ids = [];
    defaulter_date = {}

    (data || []).each do |row|
      patient_ids << row['patient_id'].to_i
      defaulter_date[row['patient_id'].to_i] = row['outcome_date']
    end
  
    clients = ActiveRecord::Base.connection.select_all("SELECT 
    i.identifier, p.birthdate, p.gender, n.given_name, 
    n.family_name, p.person_id, p.birthdate_estimated
    FROM temp_earliest_start_date t 
    INNER JOIN person p ON p.person_id = t.patient_id AND p.voided = 0
    RIGHT JOIN person_address a ON a.person_id = t.patient_id AND a.voided = 0
    RIGHT JOIN person_name n ON n.person_id = t.patient_id AND n.voided = 0
    RIGHT JOIN patient_identifier i ON i.patient_id = t.patient_id AND i.voided = 0 
    AND i.identifier_type IN(2,3)
    WHERE p.person_id IN(#{patient_ids.join(',')})
    GROUP BY i.identifier, p.birthdate, p.gender, 
    n.given_name, n.family_name, 
    p.person_id, p.birthdate_estimated;")

    clients_formatted = [];

    (clients || []).each do |c|
      clients_formatted << {
        given_name: c['given_name'], family_name: c['family_name'],
        birthdate: c['birthdate'], gender: c['gender'], person_id: c['person_id'],
        npid: c['identifier'], birthdate_estimated: c['birthdate_estimated'],
        defaulter_date: defaulter_date[c['person_id'].to_i]
      }
    end

    return clients_formatted
    

  end

end
