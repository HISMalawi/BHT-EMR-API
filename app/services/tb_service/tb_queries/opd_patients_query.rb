include ModelUtils

class TbService::TbQueries::OpdPatientsQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('OPD Program')
  end

  def ref (start_date, end_date)
    @relation.joins(:patient_programs)\
             .where(patient_program: { program_id: @program,
                                       date_enrolled: start_date..end_date })
  end

  module Scopes
    def age_range (min, max = 9_000)
      joins(:person)\
      .where('TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) BETWEEN ? AND ?', min, max)
    end
  end
end