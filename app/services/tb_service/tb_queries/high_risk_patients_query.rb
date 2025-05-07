include ModelUtils

class TbService::TbQueries::HighRiskPatientsQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
    @program = program('TB Program')
  end

  def ref (start_date, end_date)
    type = encounter_type('TB_Initial')
    @relation.joins(encounters: :observations)\
             .where(encounter: { program_id: @program,
                                 encounter_type: type,
                                 encounter_datetime: start_date..end_date })
  end

  module Scopes
    def miners
      screening_criteria = concept('TB screening criteria')
      value = concept('Minning Communities')
      where(obs: { concept_id: screening_criteria, value_coded: value })\
      .distinct
    end

    def current_miners
      screening_criteria = concept('TB screening criteria')
      value = concept('Current miners')
      where(obs: { concept_id: screening_criteria, value_coded: value })\
      .distinct
    end

    def ex_miners
      screening_criteria = concept('TB screening criteria')
      value = concept('Ex-miners')
      where(obs: { concept_id: screening_criteria, value_coded: value })\
      .distinct
    end

    def prisoners
      screening_criteria = concept('TB screening criteria')
      value = concept('Prison')
      where(obs: { concept_id: screening_criteria, value_coded: value })\
      .distinct
    end

    def health_care_workers
      screening_criteria = concept('TB screening criteria')
      value = concept('Health care worker')
      where(obs: { concept_id: screening_criteria, value_coded: value })\
      .distinct
    end
  end
end