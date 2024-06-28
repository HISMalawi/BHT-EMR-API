module VaccineScheduleService
  # This module is used to get the vaccine schedule for a patient
  def self.vaccine_schedule(patient)
    # Get Vaccine Schedule
    # begin
      # Immunization Drugs
      immunization_drugs = ConceptSet.joins(concept: %i[concept_names drugs])
                                     .where(concept_set: ConceptName.where(name: 'Immunizations').pluck(:concept_id))
                                     .select('concept.concept_id, concept_name.name, drug.drug_id')
                 
      # For each of these get the window period and schedule
      immunization_with_window = immunization_drugs.map do |immunization_drug| 
        window_period = vaccine_attribute(immunization_drug.concept_id, 'Immunization window period')
        milestone = vaccine_attribute(immunization_drug.concept_id, 'Immunization milestones')
        {drug_id: immunization_drug.drug_id, drug_name: immunization_drug.name, window_period:, milestone:}
      end

      # if patient.gender == ('M' || 'Male')
      #   female_immunization_concepts = ConceptName.where(name: 'Female only Immunizations').pluck(:concept_id)
      #   female_concepts = ConceptSet.where(concept_set: female_immunization_concepts).pluck(:concept_id)
      #   concept_set = ConceptSet.where(concept_set: immunization_concepts)
      #                           .where.not(concept_id: female_concepts).pluck(:concept_id)
      # else
      #   concept_set = ConceptSet.where(concept_set: immunization_concepts).pluck(:concept_id)
      # end
      # schedule = Drug.joins(concept: :concept_names).where(concept_id: concept_set)
      #                .select('concept_name.concept_id AS concept_id,
      #                         concept_name.name AS concept_name,
      #                         drug.drug_id AS drug_id,
      #                         drug.name AS drug_name')

      vaccines_given = administered_vaccines(patient.person_id, immunization_with_window.pluck(:drug_id))
      grouped_immuminzations = immunization_with_window.group_by { | immunizations | immunizations[:milestone] }
      return {vaccine_schedule: format_schedule(grouped_immuminzations, vaccines_given, patient.birthdate)}
    # rescue => e
      return {error: e.message}
    #end
  end

  def self.vaccine_attribute(drug_id, attribute_type)
    ConceptSet.joins(concept: :concept_names)
              .where(concept_set: ConceptName.where(name: attribute_type).pluck(:concept_id))
              .where(concept_id: ConceptSet.where(concept_set: drug_id).pluck(:concept_id))
              .select('concept_name.name').first&.name
  end



 

  def self.format_schedule(schedule, vaccines_given, patient_dob)
    schedule.map.with_index(1) do |(milestone_name, antigens), index|
      {
        visit: index,
        milestone_status: milestone_status(milestone_name, patient_dob),
        age: milestone_name,
        antigens: antigens.map { |drug|
          vaccine_given = vaccines_given.find { |vaccine| vaccine[:drug_inventory_id] == drug[:drug_id] }
          {
            drug_id: drug[:drug_id],
            drug_name: drug[:drug_name],
            window_period: drug[:window_period],
            status: vaccine_given ? 'administered' : 'pending',
            date_administered: vaccine_given ? vaccine_given[:obs_datetime]&.strftime('%d/%b/%Y %H:%M:%S') : nil,
            vaccine_batch_number: vaccine_given ? vaccine_given[:batch_number] : nil
          }
        }
      }
    end
  end

  def self.administered_vaccines(patient_id, drugs)
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

  def self.get_batch_id(order_id)
     Observation.where(concept_id: ConceptName.where(name: 'Batch Number').pluck(:concept_id), order_id:).first&.value_text
  end

  
  def self.milestone_status(milestone, dob)
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