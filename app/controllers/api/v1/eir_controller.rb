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
          vaccine_given = vaccines_given.find { |vaccine| vaccine.drug_inventory_id == item.drug_id }
          {
            concept_id: item.concept_id,
            drug_id: item.drug_id,
            drug_name: item.drug_name,
            status: vaccine_given ? 'administered' : 'pending',
            date_administered: vaccine_given&.obs_datetime&.strftime('%d/%b/%Y %H:%M:%S')
          }
        }
      }
    end
  end

  def administered_vaccines(patient_id, drugs)
    Observation.joins(order: :drug_order)
               .where(drug_order: { drug_inventory_id: drugs }, person_id: patient_id)
               .select(:obs_datetime, :drug_inventory_id)
  end

  def milestone_status(milestone, dob)
    today = Date.today

    if milestone.casecmp('At Birth').zero?
      if today == dob
        return 'current'
      elsif today > dob
        return 'passed'
      else
        return 'upcoming'
      end
    elsif milestone.include?('weeks')
      milestone_weeks = milestone.split.first.to_i
      weeks = (today - dob).to_i / 7
      if milestone ==  weeks.to_i
        return 'current'
      else
        return weeks > milestone_weeks ? 'passed' : 'upcoming'
      end
    elsif milestone.include?('months')
      milestone_months = milestone.split.first.to_i
      months = (today.year * 12 + today.month) - (dob.year * 12 + dob.month)
      if milestone_months == months
        return 'current'
      else
        return months > milestone_months ? 'passed' : 'upcoming'
      end
    elsif milestone.include?('years')
      milestone_years = milestone.split.first.to_i
      years = today.year - dob.year
      if milestone_years == years
        return 'current'
      else
        return years > milestone_years ? 'passed' : 'upcoming'
      end
    end
  end
end
