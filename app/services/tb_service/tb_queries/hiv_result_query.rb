include ModelUtils

class TbService::TbQueries::HivResultQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
  end

  def ref
    @relation
  end

  module Scopes
    def documented
      status = concept('HIV Status')

      joins(person: :observations)\
        .where(obs: { concept_id: status })\
        .distinct
    end

    def positive
      status = concept('HIV Status')
      positive = concept('Positive')

      joins(person: :observations)\
        .where(obs: { concept_id: status, value_coded: positive })\
        .distinct
    end
  end
end