module TBQueries
  include ModelUtils

  class ObservationsQuery
    def initialize (relation = Observation.all)
      @relation = relation
    end

    def with (name, value, start_date, end_date)
      concept = concept(name)
      answer = concept(value)

      @relation.where(concept: concept,
                      answer_concept: answer,
                      obs_datetime: start_date..end_date)
    end

    def with_timeless (name, value)
      concept = concept(name)
      answer = concept(value)

      @relation.where(concept: concept,
                      answer_concept: answer)
    end
  end
end