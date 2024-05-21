include ModelUtils

class TbService::TbQueries::IptCandidatesQuery
  def initialize (relation = Patient.all)
    @relation = relation.extending(Scopes)
  end

  def ref (start_date, end_date)
    type = encounter_type('TB_Initial')
    prog = program('TB Program')

    @relation.joins(:encounters)\
             .where(encounter: { program_id: prog,
                                 encounter_type: type,
                                 encounter_datetime: start_date..end_date,
                                 patient_id: negatives(start_date, end_date) })
  end

  def negatives (start_date, end_date)
    observation = concept('TB Status')
    value = concept('Negative')

    Patient.joins(person: :observations)\
           .where(obs: { concept_id: observation, value_coded: value, obs_datetime: start_date..end_date })
  end

  module Scopes
    def under_fives (start_date, end_date)
      five_years = 5
      joins(person: :observations)\
      .where('TIMESTAMPDIFF(YEAR, person.birthdate, NOW()) <= ?', five_years)
    end

    def on_ipt (start_date, end_date)
      ipt_patients = TbService::TbQueries::IptPatientsQuery.new.all(start_date, end_date)
      where(patient: { patient_id: ipt_patients }).distinct
    end

    def not_in_tb_program (start_date, end_date)
      where.not(patient_id: TbService::TbQueries::EnrolledPatientsQuery.new.ref(start_date, end_date))
    end
  end
end