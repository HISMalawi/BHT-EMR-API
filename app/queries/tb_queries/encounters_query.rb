include TimeUtils

class TBQueries::EncountersQuery
  def initialize ()
    @program = program('TB Program')
  end

  def by_date (date, type)
    type = encounter_type(type)
    start_time, end_time = TimeUtils.day_bounds(date)

    Encounter.where(program: @program,
                    type: type,
                    encounter_datetime: start_time..end_time)
  end
end