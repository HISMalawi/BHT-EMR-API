# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::FailuresQuery
  def initialize(relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref(start_date, end_date)
    observation = concept('Type of patient').concept_id
    value = concept('Treatment failure').concept_id
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
        .where(obs: { concept_id: ob, value_coded: yes, obs_datetime: start_date..end_date })\
        .distinct
    end
  end
end
