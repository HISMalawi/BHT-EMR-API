include TimeUtils

class TBQueries::EncountersQuery
  include ModelUtils

  def initialize (relation = Encounter.all)
    @relation = relation
    @program = program('TB Program')
  end

  def by_date (date, type)
    type = encounter_type(type)
    start_time, end_time = TimeUtils.day_bounds(date)

    @relation.where(program: @program,
                    type: type,
                    encounter_datetime: start_time..end_time)
  end

  def by_year (year, type)
    type = encounter_type(type)
    @relation.where(program: @program,
                    type: type)\
             .where('YEAR(encounter_datetime) = ?', year)
  end

  def by_month (month, type)
    type = encounter_type(type)
    @relation.where(program: @program,
                    type: type)\
             .where('MONTH(encounter_datetime) = ?', month)
  end
end