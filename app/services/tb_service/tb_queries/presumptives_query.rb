# frozen_string_literal: true

class TbService::TbQueries::PresumptivesQuery
  include ModelUtils

  def initialize(relation = Patient.all)
    @relation = relation
    @program = program('TB Program')
  end

  def undergoing_bacteriological_examination(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)

    type = encounter_type('Lab Orders')
    lab_result = encounter_type('Lab Results').encounter_type_id
    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: type,
                                 patient_id: new_cases,
                                 program_id: @program,
                                 encounter_datetime: start_date..end_date })\
             .where("encounter.patient_id NOT IN (SELECT patient_id FROM encounter WHERE
                     encounter_type=#{lab_result} AND program_id=#{@program.program_id}
                     AND voided = 0 AND encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}')")\
             .distinct
  end

  def via_xpert(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)
    type = encounter_type('Lab Orders')
    lab_result = encounter_type('Lab Results').encounter_type_id

    observation = concept('Test requested')
    procedure = concept('Xpert MTB/RIF')

    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: type, patient_id: new_cases, program_id: @program, encounter_datetime: start_date..end_date },
                    obs: { concept_id: observation, value_coded: procedure })
             .where("encounter.patient_id NOT IN (SELECT patient_id FROM encounter WHERE
                     encounter_type=#{lab_result} AND program_id=#{@program.program_id}
                     AND voided = 0 AND encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}')")\
             .distinct
  end

  def via_microscopy(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)
    type = encounter_type('Lab Orders')
    lab_result = encounter_type('Lab Results').encounter_type_id

    observation = concept('Test requested')
    procedure = concept('Smear microscopy')

    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: type, patient_id: new_cases, program_id: @program, encounter_datetime: start_date..end_date },
                    obs: { concept_id: observation, value_coded: procedure })
             .where("encounter.patient_id NOT IN (SELECT patient_id FROM encounter WHERE
                     encounter_type=#{lab_result} AND program_id=#{@program.program_id}
                     AND voided = 0 AND encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}')")\
             .distinct
  end

  def with_positive_bacteriological_examination(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)

    lab_result = encounter_type('Lab Results')
    observation = concept('TB Status')
    value = concept('Positive')

    @relation.joins(encounters: :observations)\
             .where(encounter: { program_id: @program,
                                 patient_id: new_cases,
                                 encounter_type: lab_result,
                                 encounter_datetime: start_date..end_date },
                    obs: { concept_id: observation, value_coded: value })\
             .distinct
  end

  def via_xpert_pos(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)
    lab_result = encounter_type('Lab Results')

    observation = concept('Sample One GeneXpert Result')
    result = concept('MTB Detetcted')

    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: lab_result, patient_id: new_cases, program_id: @program, encounter_datetime: start_date..end_date },
                    obs: { concept_id: observation, value_coded: result })\
             .distinct
  end

  def via_microscopy_pos(start_date, end_date)
    new_cases = initials(start_date, end_date).map(&:patient_id)
    lab_result = encounter_type('Lab Results')

    observation = concept('Sample One Microscopy Result')
    result = concept('AFB Positive')

    @relation.joins(encounters: :observations)\
             .where(encounter: { encounter_type: lab_result, patient_id: new_cases, program_id: @program, encounter_datetime: start_date..end_date },
                    obs: { concept_id: observation, value_coded: result })\
             .distinct
  end

  private

  def initials(start_date, end_date)
    initial = encounter_type('TB_Initial')
    @relation.joins(:encounters)\
             .where(encounter: { program_id: @program,
                                 encounter_type: initial,
                                 encounter_datetime: start_date..end_date })\
             .distinct
  end
end
