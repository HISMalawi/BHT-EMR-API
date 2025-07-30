# frozen_string_literal: true

include ModelUtils

class TbService::TbQueries::RetreatmentPatientsQuery
  def initialize(relation = Patient.all)
    @relation = relation.extending(Scopes)
  end

  def ref(start_date, end_date)
    observation = concept('Type of patient').concept_id
    concept_ids = "(#{retreatment_concepts.map(&:concept_id).join(',')})"

    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: program('TB Program'), date_enrolled: start_date..end_date })\
             .where("patient_program.patient_id IN
                    (SELECT person_id FROM obs WHERE concept_id=#{observation} AND value_coded IN #{concept_ids}
                    AND voided = 0 AND obs_datetime BETWEEN '#{start_date}' AND '#{end_date}')")
  end

  def retreatment_concepts
    names = ['Treatment Failure', 'Return after lost to follow up', 'Other', 'Unknown']
    concepts = ConceptName.select(:concept_id).distinct\
                          .where(name: names)
  end

  module Scopes
    def with_clinical_pulmonary_tuberculosis(start_date, end_date)
      diagnosis = encounter_type('Diagnosis')

      pulm = 1549 # duplicate names preventing name resolution

      joins(encounters: :observations)\
        .where(encounter: { program_id: program('TB Program'),
                            encounter_type: diagnosis,
                            encounter_datetime: start_date..end_date },
               obs: { value_coded: pulm })\
        .distinct
    end

    def with_eptb_tuberculosis(start_date, end_date)
      ob = concept('Type of tuberculosis')
      eptb = concept('Extrapulmonary tuberculosis (EPTB)')

      joins(person: :observations)\
        .where(obs: { concept_id: ob, value_coded: eptb, obs_datetime: start_date..end_date })
    end

    def with_mtb_through_xpert(start_date, end_date)
      mtb_detected = concept('MTB Detetcted')
      joins(person: :observations)\
        .where(obs: { value_coded: mtb_detected, obs_datetime: start_date..end_date })\
        .distinct
    end

    def smear_positive(start_date, end_date)
      smear_positive = concept('AFB Positive')
      joins(person: :observations)\
        .where(obs: { value_coded: smear_positive, obs_datetime: start_date..end_date })\
        .distinct
    end

    def with_hiv
      hiv_status = concept('HIV Status')
      positive = concept('Positive')

      joins(person: :observations)\
        .where(obs: { concept_id: hiv_status, value_coded: positive })\
        .distinct
    end

    def age_range(min, max)
      joins(:person)\
        .where("TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) BETWEEN #{min} AND #{max}")
    end

    def on_cpt
      cpt_started = concept('CPT started')
      yes_answer = concept('Yes')

      joins(person: :observations)\
        .where(obs: { concept_id: cpt_started, value_coded: yes_answer })\
        .distinct
    end
  end
end
