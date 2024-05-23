# frozen_string_literal: true

module TbQueries
  class PersonsQuery
    def initialize(relation = Person.all)
      @relation = relation
    end

    def group_by_gender(ids)
      @relation.select('gender', 'COUNT(*) AS count')
               .where(person_id: ids)
               .group(:gender)
    end
  end
end
