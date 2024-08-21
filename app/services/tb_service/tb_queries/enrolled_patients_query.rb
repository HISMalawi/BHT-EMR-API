# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::EnrolledPatientsQuery
  TB_NUMBER_REGEX = '^[A-Za-z]+\/(TB|IPT)\/[0-9]+\/[0-9]+$'

  def initialize(relation = Patient.includes(:patient_identifiers, person: :addresses, patient_programs: :patient_states).all)
    @relation = relation.extending(Scopes)
  end

  def ref(start_date, end_date)
    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: program('TB Program'), date_enrolled: start_date..end_date })
  end

  module Scopes
    def without_tb_number
      tb_number_concept = concept('TB registration number').concept_id
      where("patient_program.patient_id NOT IN (SELECT person_id FROM obs WHERE concept_id = #{tb_number_concept} AND voided = 0)")
    end

    def bad_tb_number
      tb_number_concept = concept('TB registration number')
      joins(person: :observations)\
        .where(obs: { concept_id: tb_number_concept })
        .where("obs.value_text NOT REGEXP '#{TB_NUMBER_REGEX}' OR SUBSTRING_INDEX(obs.value_text, '/', -1) != (EXTRACT(YEAR FROM obs_datetime))")
    end

    def hiv_result_documented
      status = concept('HIV Status')

      joins(person: :observations)\
        .where(obs: { concept_id: status })\
        .distinct
    end

    def hiv_status_positive
      status = concept('HIV Status')
      positive = concept('Positive')

      joins(person: :observations)\
        .where(obs: { concept_id: status, value_coded: positive })\
        .distinct
    end

    def with_pulmonary_tuberculosis (start_date, end_date)
      ob = concept('Type of tuberculosis')
      pulm = 1549 # duplicate names preventing name resolution

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: pulm, obs_datetime: start_date..end_date })
    end

    def age_range (min, max)
      joins(:person).where("TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) BETWEEN #{min} AND #{max}")
    end
  end
end
