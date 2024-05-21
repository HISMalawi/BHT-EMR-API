include ModelUtils

class TbService::TbQueries::MdrQuery
  MDR_STATE_ID = 174
  TB_STATE = 92

  def initialize (relation = Patient.all)
    @relation = relation
    @program = program('TB Program')
  end

  def culture_done(start_date, end_date)
     @relation.joins(person: :observations)\
              .where(obs: {
                concept_id: concept('Procedure type').concept_id,
                value_coded: concept('Culture and DST').concept_id,
                obs_datetime: start_date..end_date
              })
  end

  def culture_not_done(start_date, end_date)
     @relation.joins(person: :observations)\
              .where.not(obs: {
                concept_id: concept('Procedure type').concept_id,
                value_coded: concept('Culture and DST').concept_id,
                obs_datetime: start_date..end_date
              })
  end

  def clinical_mdr(start_date, end_date)
    @relation.joins(encounters: :observations)\
            .where(encounter: { encounter_type: encounter_type('Diagnosis'),
                                program_id: @program,
                                encounter_datetime: start_date..end_date,
                              })
            .where(obs: {concept_id: concept('TB drug resistance').concept_id})
            .distinct
  end

  def confirmed_mdr(start_date, end_date)
    @relation.joins(encounters: :observations)\
            .where(encounter: { encounter_type: encounter_type('Lab Results'),
                                program_id: @program,
                                encounter_datetime: start_date..end_date,
                              })
            .where(obs: {concept_id: concept('Tuberculosis known to be resistant').concept_id, value_coded: concept('Yes').concept_id})
            .distinct
  end

  def confirmed_rif(start_date, end_date)
    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: encounter_type('Lab Results'),
                                  program_id: @program,
                                  encounter_datetime: start_date..end_date,
                                })
             .where(obs: {
                     concept_id: concept('Rifampicin resistance confirmed'),
                     value_coded: concept('Yes').concept_id
              })
  end

  def previously_on_firstline_treatment(start_date)
      @relation.joins(patient_programs: :patient_states)\
               .where(patient_program: { program_id: @program }, patient_state: { state: TB_STATE })\
               .where('DATE(patient_state.start_date) < DATE(?) AND patient_state.end_date IS NOT NULL', start_date)
  end

  def previously_on_secondline_treatment(start_date)
      @relation.joins(patient_programs: :patient_states)\
               .where(patient_program: { program_id: @program }, patient_state: { state: MDR_STATE_ID})\
               .where('DATE(patient_state.start_date) < DATE(?) AND patient_state.end_date IS NOT NULL', start_date)
  end
end