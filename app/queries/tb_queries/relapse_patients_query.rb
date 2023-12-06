class TBQueries::RelapsePatientsQuery
  STATES = {
    :RX => 92, # in treatment
    :RP => 168, # relapse
    :CR => 97 #cured
  }.freeze

  def initialize
    @program = program('TB Program')
  end

  def bacteriologically_confirmed (start_date, end_date)
    type = encounter_type('Lab Results').encounter_type_id
    value = concept('Positive').concept_id
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT States.patient_id
        FROM
        (
          SELECT DISTINCT(patient_id), patient_state.date_created
          FROM
            patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
          WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
        ) AS States
        JOIN
        (
          SELECT DISTINCT(person_id), obs_datetime
          FROM encounter JOIN obs USING(encounter_id)
          WHERE
            value_coded = '#{value}' AND encounter_datetime BETWEEN "#{start_date}"
            AND "#{end_date}" AND encounter_type = '#{type}' AND encounter.voided = 0
            AND encounter.program_id = '#{@program.program_id}'
        ) AS BactConfirmed
        ON States.patient_id = BactConfirmed.person_id
        WHERE BactConfirmed.obs_datetime <= States.date_created;
      SQL
    )
  end

  def clinically_confirmed (start_date, end_date)
    type = encounter_type('Diagnosis').encounter_type_id
    value = concept('Positive').concept_id
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT States.patient_id
        FROM
        (
          SELECT DISTINCT(patient_id), patient_state.date_created
          FROM
            patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
          WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
        ) AS States
        JOIN
        (
          SELECT DISTINCT(person_id), obs_datetime
          FROM encounter JOIN obs USING(encounter_id)
          WHERE
            value_coded = '#{value}' AND encounter_datetime BETWEEN "#{start_date}"
            AND "#{end_date}" AND encounter_type = '#{type}' AND encounter.voided = 0
            AND encounter.program_id = '#{@program.program_id}'
        ) AS BactConfirmed
        ON States.patient_id = BactConfirmed.person_id
        WHERE BactConfirmed.obs_datetime <= States.date_created;
      SQL
    )
  end

  def clinical_pulmonary (start_date, end_date)
    type = encounter_type('Diagnosis').encounter_type_id
    value = concept('Positive').concept_id
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT States.patient_id
        FROM
        (
          SELECT DISTINCT(patient_id), patient_state.date_created
          FROM
            patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
          WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
        ) AS States
        JOIN
        (
          SELECT DISTINCT(person_id), obs_datetime
          FROM encounter JOIN obs USING(encounter_id)
          WHERE
            value_coded = '#{value}' AND encounter_datetime BETWEEN "#{start_date}"
            AND "#{end_date}" AND encounter_type = '#{type}' AND encounter.voided = 0
            AND encounter.program_id = '#{@program.program_id}'
        ) AS ClinicConfirmed
        ON States.patient_id = ClinicConfirmed.person_id
        WHERE ClinicConfirmed.obs_datetime <= States.date_created;
      SQL
    )
  end

  def eptb (start_date, end_date)
    value = concept('Extrapulmonary tuberculosis (EPTB) ')
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT States.patient_id
        FROM
        (
          SELECT DISTINCT(patient_id), patient_state.date_created
          FROM
            patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
          WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
        ) AS States
        JOIN
        (
          SELECT DISTINCT(person_id), obs_datetime
          FROM obs
          WHERE value_coded = '#{value}' AND obs_datetime BETWEEN "#{start_date}" AND "#{end_date}" AND obs.voided = 0
        ) AS Eptb
        ON States.patient_id = Eptb.person_id
        WHERE Eptb.obs_datetime <= States.date_created;
      SQL
    )
  end

  def with_hiv (start_date, end_date)
    concept = concept('HIV Status').concept_id
    value = concept('Positive').concept_id
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT States.patient_id
        FROM
        (
          SELECT DISTINCT(patient_id), patient_state.date_created
          FROM
            patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
          WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
        ) AS States
        JOIN
        (
          SELECT DISTINCT(person_id), obs_datetime
          FROM obs
          WHERE concept_id = '#{concept}' AND value_coded = '#{value}' AND obs.voided = 0
        ) AS Hiv
        ON States.patient_id = Hiv.person_id;
      SQL
    )
  end

  def relapse_patients (start_date, end_date)
    ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT DISTINCT(patient_id), patient_state.date_created
        FROM
          patient JOIN patient_program USING(patient_id)
          JOIN patient_state USING(patient_program_id)
        WHERE patient_state.state = '#{STATES[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
      SQL
    )
  end
end