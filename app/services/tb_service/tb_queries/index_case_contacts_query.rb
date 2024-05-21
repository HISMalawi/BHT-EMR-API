include ModelUtils

class TbService::TbQueries::IndexCaseContactsQuery
  def initialize (relation = Relationship.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref (index_cases, start_date, end_date)
    type = RelationshipType.find_by(a_is_to_b: 'TB patient')
    @relation.where(relationship: type,
                    person_a: index_cases)
  end

  module Scopes
    def with_tb (start_date, end_date)
      obsvervation = concept('TB Status')
      value = concept('Positive')

      joins(relation: :observations)\
      .where(obs: { concept_id: obsvervation, value_coded: value, obs_datetime: start_date..end_date })
    end

    def under_five
      five_years = 5
      joins(relation: :observations)\
      .where('TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) <= ?', five_years).distinct
    end
  end
end