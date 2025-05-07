include ModelUtils

class TbService::TbQueries::IndexCasesQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref (start_date, end_date)
    @relation.merge(index_cases(start_date, end_date))
  end

  def index_cases (start_date, end_date)
    pulmonary_tb = 1549 # name conflict preventing concept resolution
    Patient.joins(encounters: :observations)\
           .where(encounter: { program_id: @program,
                               encounter_type: [encounter_type('Diagnosis'), encounter_type('Lab Results')],
                               encounter_datetime: start_date..end_date },
                  obs: { value_coded: pulmonary_tb })
  end

  module Scopes
    def cases
      distinct
    end
  end
end