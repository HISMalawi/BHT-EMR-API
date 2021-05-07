# frozen_string_literal: true

module ARTService
class VLReminder
  include ModelUtils

  def initialize(patient_id:, date: Date.today)
    @program = Program.find_by_name 'HIV PROGRAM'
    @patient = Patient.find(patient_id)
    @date = date.to_date
    @earliest_start_date = get_earliest_start_date
  end

  def vl_reminder_info
    begin
      months_gone = ActiveRecord::Base.connection.select_one <<EOF
      SELECT TIMESTAMPDIFF(MONTH, DATE('#{@earliest_start_date.to_date}'), DATE('#{@date}')) AS months;
EOF

      months_gone = months_gone['months'].to_i
    rescue
      return {}
    end

    milestones = [6]
    start_month = 6

    1.upto(100).each do |y|
      milestones << (start_month += 12)
    end

    vl_eligibility = {
      eligibile: false,
      milestone: nil, period_on_art: months_gone,
      earliest_start_date: @earliest_start_date.to_date,
      skip_milestone: false, message: nil
     }

    if milestones.include?(months_gone) || milestones.include?(months_gone + 1) ||
      milestones.include?(months_gone + 2) || milestones.include?(months_gone + 3)
      value_coded  = ConceptName.find_by_name('Delayed milestones').concept_id
      value_coded2 = ConceptName.find_by_name('Tests ordered').concept_id

      obs = Observation.where(person_id: @patient.id, value_numeric: months_gone,
        concept_id: ConceptName.find_by_name('HIV viral load').concept_id,
        value_coded: [value_coded,value_coded2]).\
        order('obs_datetime DESC').first

      unless obs.blank?
        provider = PersonName.where(person_id: Encounter.find(obs.encounter_id).provider_id).last
        if obs.value_coded == value_coded
          vl_eligibility[:message] = "VL reminder set for next milestone"
          vl_eligibility[:message] += " by #{provider.given_name} #{provider.family_name}" unless provider.blank?
        else
          vl_eligibility[:message] = "VL test ordered on #{obs.obs_datetime.strftime('%d/%b/%Y')}"
          vl_eligibility[:message] += " by #{provider.given_name} #{provider.family_name}" unless provider.blank?
        end
      end

      vl_eligibility[:eligibile] = true
      vl_eligibility[:milestone] = months_gone
      vl_eligibility[:skip_milestone] = obs.blank? ? false : true
    end

    if vl_eligibility[:eligibile] == false
      milestones.each do |m|
        if (months_gone == (m - 1))
          vl_eligibility[:milestone] = m
          vl_eligibility[:message] = 'VL is due in a month time.'
          vl_eligibility[:message] += "<br /> Client's start date: #{@earliest_start_date.to_date.strftime('%d/%b/%Y')}"
        end
      end
    end

    return vl_eligibility
  end

  private

  def get_earliest_start_date
    patient_eng = ARTService::PatientsEngine.new(program: @program)
    date_enrolled = patient_eng.find_patient_date_enrolled(@patient)
    earliest_start_date = patient_eng.find_patient_earliest_start_date(@patient, date_enrolled)
    return earliest_start_date
  end


 end
end
