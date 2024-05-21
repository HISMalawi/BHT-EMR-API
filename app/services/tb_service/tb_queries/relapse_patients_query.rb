# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::RelapsePatientsQuery
  STATES = {
    RP: 168
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
    def bact_confirmed(start_date, end_date)
      ob = concept('Bacteriologic-ally Diagnosed')
      yes = concept('Yes')

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: yes, obs_datetime: start_date..end_date })
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

    def eptb (start_date, end_date)
      ob = concept('Type of tuberculosis')
      eptb = concept('Extrapulmonary tuberculosis (EPTB)')

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: eptb, obs_datetime: start_date..end_date })
    end

    def with_hiv
      hiv_status = concept('HIV Status')
      positive = concept('Positive')

      joins(person: :observations)\
        .where(obs: { concept_id: hiv_status, value_coded: positive })
    end

    def on_cpt
      cpt_started = concept('CPT started')
      yes_answer = concept('Yes')

      joins(person: :observations)\
        .where(obs: { concept_id: cpt_started, value_coded: yes_answer })\
        .distinct
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
