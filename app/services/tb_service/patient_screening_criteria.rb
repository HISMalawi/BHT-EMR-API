require 'date'
class TbService::PatientScreeningCriteria
  include ModelUtils

  def initialize(patient_id:, program_id:, date:)
    @patient = Patient.find(patient_id)
    @program_id = program_id
    @patient_id = patient_id
    @date = date
  end

  def screen
    criteria_list = []

    if patient_under_fourteen?
      criteria_list << concept_name('Children between5 and14')
    end

    if was_smear_positive_on_third_month?
      criteria_list << concept_name('Smear positive TB')
    end

    if regimen_failure?
      criteria_list << concept_name('Regimen failure')
    end

    if mdr_contact?
      criteria_list << concept_name('MDR-TB contact')
    end

    if patient_has_extrapulmonary_tb?
      criteria_list << concept_name('Extrapulmonary tuberculosis (EPTB)')
    end

    if return_after_lost_to_followup?
      criteria_list << concept_name('Return after lost to follow up')
    end

    criteria_list
  end

  def patient_under_fourteen?
    (@patient.age >= 5 && @patient.age <= 14)
  end

  def patient_has_extrapulmonary_tb?
    tb_form = concept_name 'Form of tuberculosis'
    eptb = concept_name 'Extrapulmonary tuberculosis (EPTB)'

    Observation.where(
      'person_id = ? AND concept_id = ? AND value_coded = ?',
      @patient_id, tb_form.concept_id, eptb.concept_id
    ).exists?
  end

  def regimen_failure?
    regimen_failure = concept_name 'Regimen failure'
    patient_state_service = PatientStateService.new
    begin
      current_state = patient_state_service.find_patient_state @program_id, @patient_id
      program_state = ProgramWorkflowState\
                        .where('program_workflow_state_id = ?', current_state.state)\
                        .order(date_created: :desc)\
                        .first
      (program_state.concept_id === regimen_failure.concept_id)
    rescue StandardError
      false
    end
  end

  def mdr_contact?
    r_service = PersonRelationshipService.new Person.find(@patient_id)
    relations = r_service.find_relationships nil
    has_contact = false
    mdr_program = 5 # MDR-TB PROGRAM
    relations.each do |relation|
      p_program = PatientProgram.find_by(program_id: mdr_program, patient_id: relation.person_a)
      if !p_program.blank?
        has_contact = true
        break
      end
    end
    has_contact
  end

  def return_after_lost_to_followup?
    lost_to_followup = concept_name 'Return after lost to follow up'
    patient_state_service = PatientStateService.new
    begin
      current_state = patient_state_service.find_patient_state @program_id, @patient_id
      program_state = ProgramWorkflowState\
                        .where('program_workflow_state_id = ?', current_state.state)\
                        .order(date_created: :desc)\
                        .first
      (program_state.concept_id === lost_to_followup.concept_id)
    rescue StandardError
      false
    end
  end

  def was_smear_positive_on_third_month?
    afb_positive = 9832
    samples = [
      concept_name('Sample One Microscopy Result').concept_id,
      concept_name('Sample Two Microscopy Result').concept_id
    ]
    observations = Observation.where(
      'person_id = ? AND concept_id IN (?)', @patient_id, samples
    ).order(obs_datetime: :desc)

    if observations.length >= 4
      sample_one = observations[0]
      sample_two = observations[1]
      latest_result_date = nil
      initial_result_date = observations.last.obs_datetime

      if sample_one.value_coded === afb_positive
        latest_result_date = sample_one.obs_datetime
      elsif sample_two.value_coded === afb_positive
        latest_result_date = sample_two.obs.datetime
      else
        return false
      end
      duration = (
        Date.parse(latest_result_date.strftime('%F'))-Date.parse(initial_result_date.strftime('%F'))
      ).to_i
      return duration >= 91
    end
    return false
  end
end
