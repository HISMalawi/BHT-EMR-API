class Api::V1::EirController < ApplicationController
  def vaccine_schedule
    # Get Vaccine Schedule
    begin
      patient = Person.find(immunization_schedule_params[:patient_id].to_i)
      immunization_concepts = ConceptName.where(name: 'Immunizations').pluck(:concept_id)
      if patient.gender == ('M' || 'Male')
        female_immunization_concepts = ConceptName.where(name: 'Female only Immunizations').pluck(:concept_id)
        female_concepts = ConceptSet.where(concept_set: female_immunization_concepts).pluck(:concept_id)
        concept_set = ConceptSet.where(concept_set: immunization_concepts)
                                .where.not(concept_id: female_concepts).pluck(:concept_id)
      else
        concept_set = ConceptSet.where(concept_set: immunization_concepts).pluck(:concept_id)
      end
      schedule = Drug.joins(concept: :concept_names).where(concept_id: concept_set)
                     .select('concept_name.concept_id AS concept_id,
                              concept_name.name AS concept_name,
                              drug.drug_id AS drug_id,
                              drug.name AS drug_name')
      vaccines_given = administered_vaccines(patient.person_id, schedule.pluck(:drug_id))
      render json: {vaccinSchedule: format_schedule(schedule, vaccines_given, patient.birthdate)}, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: {error: 'Patient not found'}, status: :not_found
    end
  end


  private

  def immunization_schedule_params
    params.require(:patient_id)
    params.permit(:patient_id)
    {patient_id: params[:patient_id]}
  end

  def format_schedule(schedule, vaccines_given, patient_dob)
    schedule.group_by(&:concept_name).map.with_index(1) do |(concept_name, antigens), index|
      {
        visit: index,
        milestone_status: milestone_status(concept_name, patient_dob),
        age: concept_name,
        antigens: antigens.map { |item|
          vaccine_given = vaccines_given.find { |vaccine| vaccine[:drug_inventory_id] == item.drug_id }
          {
            concept_id: item.concept_id,
            drug_id: item.drug_id,
            drug_name: item.drug_name,
            status: vaccine_given ? 'administered' : 'pending',
            date_administered: vaccine_given ? vaccine_given[:obs_datetime]&.strftime('%d/%b/%Y %H:%M:%S') : nil,
            vaccine_batch_number: vaccine_given ? vaccine_given[:batch_number] : nil
          }
        }
      }
    end
  end

  def administered_vaccines(patient_id, drugs)
    Observation.joins(order: :drug_order)
               .where(drug_order: { drug_inventory_id: drugs }, person_id: patient_id)
               .select(:obs_datetime, :drug_inventory_id, :order_id).map do |obs|
      {
        obs_datetime: obs.obs_datetime,
        drug_inventory_id: obs.drug_inventory_id,
        batch_number: get_batch_id(obs.order_id)
      }
    end
  end

  def get_batch_id(order_id)
     Observation.where(concept_id: ConceptName.where(name: 'Batch Number').pluck(:concept_id), order_id: order_id).first&.value_text
  end

  
  def milestone_status(milestone, dob)
    today = Date.today

    if milestone.casecmp('At Birth').zero?
      if today == dob
        'current'
      elsif today > dob
        'passed'
      else
        'upcoming'
      end
    elsif milestone.include?('weeks')
      milestone_weeks = milestone.split.first.to_i
      age_in_weeks = (today - dob).to_i / 7
      return 'current' if milestone ==  age_in_weeks.to_i

      age_in_weeks > milestone_weeks ? 'passed' : 'upcoming'
    elsif milestone.include?('months')
      milestone_months = milestone.split.first.to_i
      age_in_months = (today.year * 12 + today.month) - (dob.year * 12 + dob.month)
      return 'current' if milestone_months == age_in_months

      age_in_months > milestone_months ? 'passed' : 'upcoming'
    elsif milestone.include?('years')
      milestone_years = milestone.split.first.to_i
      age_in_years = today.year - dob.year
      case milestone_years
      when 9
        return 'current' if age_in_years >= 9 && age_in_years <= 14
      when 12
        return 'current' if age_in_years > 12
      when 15
        return 'current' if age_in_years >= 15 && age_in_years <= 45
      when 18
        return 'current' if age_in_years >= 18
      else
        return 'current' if milestone_years == age_in_years

        age_in_years > milestone_years ? 'passed' : 'upcoming'
      end
    end
  end
end
