module TBQueries
  include ModelUtils

  class ObservationsQuery
    def initialize (relation = Observation.all)
      @relation = relation
      @program = program('TB Program')
    end

    def with_answer (ids, value, start_date, end_date)
      answer = concept(value)

      @relation.select(:person_id).distinct\
               .where(answer_concept: answer,
                      obs_datetime: start_date..end_date,
                      person_id: ids)
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