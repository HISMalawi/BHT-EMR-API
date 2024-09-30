include ModelUtils

class TbService::TbQueries::IptPatientsQuery
  ON_IPT = 173

  def initialize (relation = Patient.all)
    @relation = relation
    @program = program('TB Program')
  end

  def all (start_date, end_date)
    @relation.joins(patient_programs: :patient_states)\
             .where(patient_program: { program_id: @program,
                                       date_enrolled: start_date..end_date
                                      },
                    patient_state: { state: ON_IPT })
  end

  def completed (start_date, end_date)
    @relation.joins(patient_programs: :patient_states)\
             .where(patient_program: { program_id: @program,
                        date_enrolled: start_date..end_date
                      }, patient_state: { state: ON_IPT, end_date: start_date..end_date})
  end
end