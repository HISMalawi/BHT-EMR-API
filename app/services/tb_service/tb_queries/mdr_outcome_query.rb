include ModelUtils

class TbService::TbQueries::MdrOutcomeQuery
  def initialize (relation = Patient.all)
    @relation = relation
    @program = program('TB Program')
  end

  def ref (start_date, end_date)
      @relation.joins(encounters: :observations)
               .where(encounter: {
                   encounter_type: encounter_type('EXIT FROM CARE'),
                   encounter_datetime:start_date..end_date
                })
               .where(obs: {
                   concept_id: concept('Patient tracking state').concept_id,
                   value_text: 'Multi drug resistance treatment'
                })
  end

  def outcome(outcome, patients, start_date, end_date)
    @relation.joins(encounters: :observations)
             .where(encounter: {
                encounter_type: encounter_type('EXIT FROM CARE'),
                encounter_datetime:start_date..end_date})
             .where(obs: {
                concept_id: concept('Reason for exiting care').concept_id,
                value_text: outcome})
             .where(patient_id: patients).distinct
  end
end