# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::UnknownTreatmentHistoryQuery
  def initialize(relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref(start_date, end_date)
    observation = concept('Type of patient').concept_id
    value = concept('Unknown').concept_id
    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: @program, date_enrolled: start_date..end_date })\
             .where("patient_program.patient_id IN
              (SELECT person_id FROM obs WHERE concept_id=#{observation} AND value_coded=#{value}
              AND voided = 0 AND obs_datetime BETWEEN '#{start_date}' AND '#{end_date}')")
  end

  module Scopes
    def pulmonary_diagnosis(start_date, end_date)
      diagnosis = encounter_type('Diagnosis')
      lab_results = encounter_type('LAB RESULTS')

      pulm = 1549 # duplicate names preventing name resolution

      joins(encounters: :observations)\
        .where(encounter: { :encounter_type => [diagnosis, lab_results]})\
        .where(encounter: { program_id: program('TB Program'),
                            encounter_datetime: start_date..end_date },
               obs: { value_coded: pulm })\
        .distinct
    end

    def bact_confirmed(start_date, end_date)
      ob = concept('Bacteriologic-ally Diagnosed')
      yes = concept('Yes')

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: yes, obs_datetime: start_date..end_date })
    end

    def eptb (start_date, end_date)
      ob = concept('Type of tuberculosis')
      eptb = concept('Extrapulmonary tuberculosis (EPTB)')

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: eptb, obs_datetime: start_date..end_date })
    end
  end
end
