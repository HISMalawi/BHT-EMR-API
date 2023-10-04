# frozen_string_literal: true

module TBQueries
  class ObservationsQuery
    def initialize(relation = Observation.all)
      @relation = relation
      @program = program('TB Program')
    end

    def with_answer(ids, value, start_date, end_date)
      answer = concept(value)

      @relation.select(:person_id).distinct\
               .where(answer_concept: answer,
                      obs_datetime: start_date..end_date,
                      person_id: ids)
    end

    def with(name, value, start_date = nil, end_date = nil)
      concept = concept(name)
      answer = concept(value)

      filter = { concept:, answer_concept: answer }
      filter[:obs_datetime] = (start_date..end_date) if start_date && end_date

      @relation.select(:person_id).distinct\
               .where(filter)
    end
  end
end
