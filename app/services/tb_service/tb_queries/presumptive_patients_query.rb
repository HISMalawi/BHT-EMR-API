include ModelUtils

class TbService::TbQueries::PresumptivePatientsQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
  end

  def ref (start_date, end_date)
    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: encounter_type('TB_Initial'),
                                 program_id: program('TB Program'),
                                 encounter_datetime: start_date..end_date,
                                 patient_id: new_cases(start_date, end_date),
                                 patient_id: with_symptoms(start_date, end_date) })
  end

  def new_cases (start_date, end_date)
    observation = concept('Type of patient').concept_id
    value = concept('New TB Case').concept_id

    Patient.joins(person: :observations)\
           .where(obs: { concept_id: observation,
                         value_coded: value,
                         obs_datetime: start_date..end_date })
  end

  def with_symptoms (start_date, end_date)
    Patient.joins(person: :observations)\
           .where(obs: { concept_id: tb_symptoms, obs_datetime: start_date..end_date })
  end

  def tb_symptoms
    [
      'Cough any duration',
      'Cough lasting >1 week',
      'Cough lasting greater than two weeks',
      'Weight loss',
      'Fever of 7 days or more',
      'Fever lasting >2 weeks',
      'Fever any duration',
      'Profuse night sweats lasting >1 week',
      'Profuse night sweats lasting >2 week',
      'Profuse night sweats any duration'
    ].map { |name| concept(name).concept_id }
  end

  module Scopes
    def cases
      distinct
    end

    def male
      joins(:person).where(person: { gender: 'M' }).distinct
    end

    def female
      joins(:person).where(person: { gender: 'F' }).distinct
    end

    def on_art
      observation = concept('On antiretrovirals')
      value = concept('Yes')
      where(obs: { concept_id: observation, value_coded: value }).distinct
    end

    def not_on_art
      observation = concept('On antiretrovirals')
      value = concept('No')
      where(obs: { concept_id: observation, value_coded: value }).distinct
    end

    def hiv_positive
      observation = concept('HIV Status')
      value = concept('Positive')
      where(obs: { concept_id: observation, value_coded: value })\
      .where('DATE(obs.obs_datetime) = DATE(encounter.encounter_datetime)')\
      .distinct
    end

    def hiv_negative
      observation = concept('HIV Status')
      value = concept('Negative')
      where(obs: { concept_id: observation, value_coded: value }).distinct
    end
  end
end