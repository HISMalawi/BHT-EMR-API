# frozen_string_literal: true

include TimeUtils

module TbQueries
  class EncountersQuery
    def initialize
      @program = program('TB Program')
    end

    def by_date(date, type)
      type = encounter_type(type)
      start_time, end_time = TimeUtils.day_bounds(date)

      Encounter.where(program: @program,
                      type:,
                      encounter_datetime: start_time..end_time)
    end
  end
end
