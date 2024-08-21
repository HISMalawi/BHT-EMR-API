include ModelUtils

class TbService::TbQueries::ScreenedPatientsQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref (start_date, end_date)
    type = encounter_type('TB_Initial')
    @relation.joins(:encounters)\
             .where(encounter: { program_id: @program,
                                 encounter_type: type,
                                 encounter_datetime: start_date..end_date })
  end

  module Scopes
  end
end