# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::RelapsePatientsQuery
  STATES = {
    :RX => 92, # in treatment
    :RP => 168, # relapse
    :CR => 97 #cured
  }.freeze

  def initialize(relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref(start_date, end_date)
    observation = concept('Type of patient').concept_id
    value = 9814 #duplicate names exist
    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: @program, date_enrolled: start_date..end_date })\
             .where("patient_program.patient_id IN
              (SELECT person_id FROM obs WHERE concept_id=#{observation} AND value_coded=#{value}
              AND voided = 0 AND obs_datetime BETWEEN '#{start_date}' AND '#{end_date}')")
  end

  
  module Scopes
    def bacteriologically_confirmed(start_date, end_date)
      bact_confirmed(start_date, end_date)
    end

    def bact_confirmed (start_date, end_date)
      type = encounter_type('Lab Results').encounter_type_id
      value = concept('Positive').concept_id
      program = program('TB Program')
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
              AND encounter.program_id = '#{program.id}'
          ) AS BactConfirmed
          ON States.patient_id = BactConfirmed.person_id
          WHERE BactConfirmed.obs_datetime <= States.date_created;
        SQL
      )
    end

    def clinically_confirmed (start_date, end_date)
      type = encounter_type('Diagnosis').encounter_type_id
      value = concept('Positive').concept_id
      program = program('TB Program')
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
              AND encounter.program_id = '#{program.id}'
          ) AS BactConfirmed
          ON States.patient_id = BactConfirmed.person_id
          WHERE BactConfirmed.obs_datetime <= States.date_created;
        SQL
      )
    end

    def clinical_pulmonary (start_date, end_date)
      type = encounter_type('Diagnosis').encounter_type_id
      value = concept('Positive').concept_id
      program = program('TB Program')
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
              AND encounter.program_id = #{program.id}
          ) AS ClinicConfirmed
          ON States.patient_id = ClinicConfirmed.person_id
          WHERE ClinicConfirmed.obs_datetime <= States.date_created;
        SQL
      )
    end

    def clinical_pulmonary(start_date, end_date)
      diagnosis = encounter_type('Diagnosis')

      pulm = 1549 # duplicate names preventing name resolution

      joins(encounters: :observations)\
        .where(encounter: { program_id: program('TB Program'),
                            encounter_type: diagnosis,
                            encounter_datetime: start_date..end_date },
               obs: { value_coded: pulm })\
        .distinct
    end

    def eptb(start_date, end_date)
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
          WHERE patient_state.state = '#{STATES[:RP]}' AND
          patient_state.end_date IS NULL
          AND patient_state.voided = 0
          AND patient_state.date_created BETWEEN '#{start_date}' AND '#{end_date}'
        SQL
      )
    end

    def started_before_art
      art_start_date = concept('ART start date').concept_id
      arv_status = concept('ARV status').concept_id
      before_tb = concept('Started ARV before TB treatment').concept_id

      joins(person: :observations)\
        .where('
          obs.concept_id = ? AND patient_program.date_enrolled < obs.value_datetime
          OR
          obs.concept_id = ? AND obs.value_coded = ?',
          art_start_date, arv_status, before_tb
        )
    end

    def on_cpt
      cpt_started = concept('CPT started')
      yes_answer = concept('Yes')

      joins(person: :observations)\
        .where(obs: { concept_id: cpt_started, value_coded: yes_answer })\
        .distinct
    end

    def started_while_art
      art_start_date = concept('ART start date').concept_id
      arv_status = concept('ARV status').concept_id
      while_tb = concept('Started ARV while on TB treatment').concept_id

      joins(person: :observations)\
      .where('
        obs.concept_id = ? AND patient_program.date_enrolled > obs.value_datetime
        OR
        obs.concept_id = ? AND obs.value_coded = ?',
        art_start_date, arv_status, while_tb)
    end

    def started_after_art
      art_start_date = concept('ART start date').concept_id
      arv_status = concept('ARV status').concept_id
      after_tb = concept('ARV not started by the time when discharged from TB treatment').concept_id

      joins(person: :observations)\
      .where('
        obs.concept_id = ? AND patient_program.date_enrolled > obs.value_datetime
        OR
        obs.concept_id = ? AND obs.value_coded = ?',
        art_start_date, arv_status, after_tb)
    end
  end
end
