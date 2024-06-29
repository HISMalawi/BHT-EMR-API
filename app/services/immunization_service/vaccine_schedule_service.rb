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

  def self.format_schedule(schedule, vaccines_given, client_dob)
    schedule.map.with_index(1) do |(milestone_name, antigens), index|
      {
        visit: index,
        milestone_status: milestone_status(milestone_name, client_dob),
        age: milestone_name,
        antigens: antigens.map { |drug|
          vaccine_given = vaccines_given.find { |vaccine| vaccine[:drug_inventory_id] == drug[:drug_id] }
          {
            drug_id: drug[:drug_id],
            drug_name: drug[:drug_name],
            window_period: drug[:window_period],
            can_administer: drug[:window_period]&.blank? ? 'Unknown' : can_administer_drug?(drug, client_dob),
            status: vaccine_given ? 'administered' : 'pending',
            date_administered: vaccine_given&.[](:obs_datetime)&.strftime('%d/%b/%Y %H:%M:%S'),
            administered_by: vaccine_given&.[](:administered_by),
            location_administered: vaccine_given&.[](:location_administered),
            vaccine_batch_number: vaccine_given&.[](:batch_number)
          }
        }
      }
    end
  end

  def self.administered_vaccines(patient_id, drugs)
    Observation.joins(person: :names)
               .joins(order: :drug_order)
               .where(drug_order: { drug_inventory_id: drugs }, person_id: patient_id)
               .select(:obs_datetime, :drug_inventory_id, :order_id, :location_id, 
                       :creator, :given_name, :family_name).map do |obs|
      {
        obs_datetime: obs.obs_datetime,
        drug_inventory_id: obs.drug_inventory_id,
        batch_number: get_batch_id(obs.order_id),
        administered_by: {
          person_id: obs.creator,
          given_name: obs.given_name,
          family_name: obs.family_name
        },
        location_administered: Location.find_by_location_id(obs.location_id).to_h
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

  def self.can_administer_drug?(drug, dob )
    return if drug[:window_period].blank?

    age = Date.today - dob
    # Handle atigens that are valid in a range of ages
    value, units = drug[:window_period].split
    case units.downcase
    when 'weeks'
      compare_age(age.to_i / 7, value)
    when 'months'
      compare_age(age.to_i / 30, value)
    when 'years'
      compare_age(age.to_i / 365, value)
    end
  end

  def self.compare_age(age, window_period)
    if window_period.include?('-')
      start_age, end_age = window_period.split('-').map(&:to_i)
      (age >= start_age) && (age <= end_age)
    else
      age <= window_period.to_i
    end
  end
end