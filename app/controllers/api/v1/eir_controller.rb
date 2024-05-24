class Api::V1::EirController < ApplicationController
  def vaccine_schedule
    # Get Administered Vaccines

    # Get Vaccine Schedule
    begin
      patient = Person.find(immunization_schedule_params[:patient_id].to_i)

      if patient.gender == 'M'
        immunization_concepts = ConceptName.where.not(name: 'Female only Immunizations').where(name: 'Immunizations').pluck(:concept_id)
      else
        immunization_concepts = ConceptName.where(name: 'Immunizations').pluck(:concept_id)
      end

      concept_set = ConceptSet.where(concept_set: immunization_concepts).pluck(:concept_id)
      schedule = Drug.joins(concept: :concept_names).where(concept_id: concept_set)
                     .select('concept_name.concept_id AS concept_id,
                              concept_name.name AS concept_name,
                              drug.drug_id AS drug_id,
                              drug.name AS drug_name')

      render json: {vaccinSchedule: format_schedule(schedule)}, status: :ok
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

  def format_schedule(schedule)
    schedule.group_by(&:concept_name).map.with_index(1) do |(concept_name, antigens), index|
      {
        visit: index,
        age: concept_name,
        antigens: antigens.map { |item| { concept_id: item.concept_id, drug_id: item.drug_id, drug_name: item.drug_name, status: '' } }
      }
    end
  end
end
