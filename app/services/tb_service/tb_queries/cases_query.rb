include ModelUtils

class TbService::TbQueries::CasesQuery
  RELAPSE_PATIENT_TYPE = 9814 #conflict resolution..
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref(start_date, end_date)
    type_of_patient = concept('Type of patient').concept_id
    patient_types = [concept('New TB Case').concept_id, RELAPSE_PATIENT_TYPE]
    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: program('TB Program'), date_enrolled: start_date..end_date })\
             .where("patient_program.patient_id IN
                    (SELECT person_id FROM obs WHERE concept_id= #{type_of_patient}
                      AND value_coded IN (#{patient_types.join(', ')})
                    AND voided = 0 AND obs_datetime BETWEEN '#{start_date}'
                    AND '#{end_date}')"
                  ).distinct
  end

  module Scopes
    def age_range(min, max)
      joins(:person)\
      .where("TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) BETWEEN #{min} AND #{max}")
    end
  end
end