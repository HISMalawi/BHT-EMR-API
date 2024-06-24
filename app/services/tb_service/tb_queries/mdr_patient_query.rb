include ModelUtils

class TbService::TbQueries::MdrPatientQuery
  MDR_STATE_ID = 174

  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref(start_date, end_date)
    @relation.joins(patient_programs: :patient_states)\
             .where(patient_program: { program_id: @program },
                    patient_state: { state: MDR_STATE_ID, start_date: start_date..end_date })
  end

  module Scopes
    def tb_status(status)
      joins(person: :observations)
        .where(obs: {
              concept_id: concept('TB status').concept_id,
              value_coded: concept(status).concept_id
          })
        .distinct
    end

    def age_range(min, max)
      joins(:person)\
      .where("TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) BETWEEN #{min} AND #{max}")
    end

    def regimen(regimen_name)
        joins(person: :observations)\
            .where(obs: { concept_id: concept('Regimen type').concept_id , value_text: regimen_name })\
    end

    def hiv_status(status)
      joins(person: :observations)\
        .where(obs: { concept_id: concept('HIV Status').concept_id, value_coded: concept(status).concept_id })\
    end

    def new_patient
      joins(person: :observations)\
          .where(obs: { concept_id: concept('Type of patient').concept_id , value_coded: concept('New patient').concept_id })\
    end

    def male
      joins(:person).where(person: { gender: 'M' })
    end

    def female
      joins(:person).where(person: { gender: 'F' })
    end

    def on_art(answer)
      joins(person: :observations).where(obs: { concept_id: concept('On antiretrovirals'), value_coded: concept(answer).concept_id })
    end
  end
end