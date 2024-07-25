module VaccineScheduleService
  # This module is used to get the vaccine schedule for a patient
  def self.vaccine_schedule(patient)
    # Get Vaccine Schedule
    # begin
    # Immunization Drugs
    if age_in_years(patient.birthdate) < 5
      immunization_drugs = immunization_drugs('Under five immunizations')
    else
      immunization_drugs = immunization_drugs('Over five immunizations')
      immunization_drugs = filter_female_specific_immunizations(immunization_drugs) if patient.gender.split.first.casecmp?('M')
    end
    
    # For each of these get the window period and schedule
    immunization_with_window = immunization_drugs.flat_map do |immunization_drug|
      vaccine_attribute(immunization_drug.concept_id, 'Immunization milestones').map do |milestone|
        { 
          milestone_name: milestone.name, 
          sort_weight: milestone.sort_weight,
          drug_id: immunization_drug.drug_id,
          drug_name: immunization_drug.name,
          window_period: vaccine_attribute(immunization_drug.concept_id, 'Immunization window period').first&.name
        }
      end
    end
    vaccines_given = administered_vaccines(patient.person_id, immunization_with_window.pluck(:drug_id))
    grouped_immunizations = immunization_with_window.group_by { | immunizations | immunizations[:milestone_name] }
    sorted_grouped_immunizations = grouped_immunizations.sort_by { |milestone| milestone[1][0][:sort_weight]}.to_h
    vaccines = format_schedule(sorted_grouped_immunizations, vaccines_given, patient.birthdate)

    return {vaccine_schedule: vaccines}
    # rescue => e
    return {error: e.message}
    #end
  end

  
  def self.make_unique(data)
    unique_data = data.each_with_object({}) do |(concept_set_id, milestone), hash|
      milestone.each do |drug|
        hash[concept_set_id] ||= []  # Initialize empty array for milestone drugs if not present
        hash[concept_set_id] << drug unless hash[concept_set_id].any? { |d| d[:drug_name] == drug[:drug_name] }
      end
    end

    unique_data
  end


  def self.age_in_years(birthdate)
    today = Date.today
    age = today.year - birthdate.year
    age -= 1 if today.month < birthdate.month || (today.month == birthdate.month && today.day < birthdate.day)
    age
  end

  def self.immunization_drugs(category)
    if category == 'Under five immunizations'
      immunizations = ConceptSet.joins(concept: %i[concept_names drugs])
                                .where(concept_set: ConceptName.where(name: category).pluck(:concept_id))
                                .group('concept.concept_id, drug.name, drug.drug_id')
                                .select('concept.concept_id, drug.name as name, drug.drug_id as drug_id')
    elsif category == 'Over five immunizations'
      immunizations = ConceptSet.joins(concept: %i[concept_names drugs])
                                .where(concept_set: ConceptName.where(name: 'Immunizations').pluck(:concept_id))
                                .where.not(concept_id: ConceptSet.where(concept_set: ConceptName.where(name: 'Under five immunizations')
                                .pluck(:concept_id)).pluck(:concept_id))
                                .group('concept.concept_id, drug.name, drug.drug_id')
                                .select('concept.concept_id, drug.name as name, drug.drug_id drug_id')
    end
    immunizations
  end
  
  def self.filter_female_specific_immunizations(immunizations)
    immunizations.reject do |immunization|
      ConceptSet.where(concept_set: ConceptName
                .where(name: 'Female only immunizations').pluck(:concept_id))
                .pluck(:concept_id).include?(immunization.concept_id)
    end
  end


 
  def self.update_milestone_status(vaccine_schedule)
    visit_one = vaccine_schedule.find { |visit| visit[:visit] == 1 }
    if visit_one[:antigens].any? { |antigen| antigen[:status] != 'administered' }
      visit_one[:milestone_status] = 'current'
      visit_one[:antigens].each do |antigen|
        antigen[:can_administer] = true if antigen[:status] == 'pending'
      end
      
      vaccine_schedule.each do |visit|
        next if visit[:visit] == 1

        visit[:milestone_status] = 'upcoming'
        visit[:antigens].each do |antigen|
          antigen[:can_administer] = false
        end
      end
    elsif visit_one[:antigens].all? { |antigen| antigen[:status] == 'administered' }
      visit_one[:milestone_status] = 'passed'
      administered_date = Date.strptime(visit_one[:antigens].first[:date_administered], "%d/%b/%Y %H:%M:%S")

      vaccine_schedule.each_with_index do |visit, index|
        next if visit[:visit] <= 1

        next_age_days = parse_age_to_days(visit[:age])
        visit[:milestone_status] = 'upcoming'

        next unless administered_date + next_age_days <= Date.today
        
        visit[:milestone_status] = 'current'
        visit[:antigens].each do |antigen|
          antigen[:can_administer] = true
        end
        break
      end
    end

    vaccine_schedule
  end

  def self.parse_age_to_days(age)
    units = {
      'day' => 1,
      'week' => 7,
      'month' => 30,
      'year' => 365
    }

    amount, unit = age.split
    amount.to_i * units[unit.downcase.chomp('s')]
  end

  def self.vaccine_attribute(drug_concept_id, attribute_type)
    ConceptSet.joins(concept: :concept_names)
              .where(concept_set: ConceptName.where(name: attribute_type).pluck(:concept_id))
              .where(concept_id: ConceptSet.where(concept_set: drug_concept_id).pluck(:concept_id))
              .select('concept_name.name, concept_set.sort_weight')
  end

  def self.format_schedule(schedule, vaccines_given, client_dob)
    schedule.map.with_index(1) do |(milestone_name, antigens), index|
      {
        visit: index,
        milestone_status: milestone_status(milestone_name, client_dob),
        age: milestone_name,
        antigens: antigens.map do |drug|
          vaccine_given = vaccines_given.find { |vaccine| vaccine[:drug_inventory_id] == drug[:drug_id] }
          {
            drug_id: drug[:drug_id],
            drug_name: drug[:drug_name],
            window_period: drug[:window_period],
            can_administer: can_administer_drug?(drug, client_dob, milestone_name),
            status: vaccine_given ? 'administered' : 'pending',
            date_administered: vaccine_given&.[](:obs_datetime)&.strftime('%d/%b/%Y %H:%M:%S'),
            administered_by: vaccine_given&.[](:administered_by),
            location_administered: vaccine_given&.[](:location_administered),
            vaccine_batch_number: vaccine_given&.[](:batch_number)
          }
        end
      }
    end
  end

  def vaccine_given?(drug_id)
    
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
        location_administered: Location.find_by_location_id(obs.location_id)
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

  def self.can_administer_drug?(drug, dob, milestone)
    return if drug[:window_period].blank?

    if milestone == 'At birth'
      milestone_days = 7
    else
      milestone_days = parse_age_to_days(milestone)
    end
    age = Date.today - dob
    # Handle atigens that are valid in a range of ages
    value, units = drug[:window_period].split
    case units.downcase
    when 'weeks'
      compare_age(age.to_i / 7, value, milestone_days / 7)
    when 'months'
      compare_age(age.to_i / 30, value, milestone_days / 30)
    when 'years'
      compare_age(age.to_i / 365, value, milestone_days / 365)
    end
  end

  def self.compare_age(age, window_period, milestone_days)
    if window_period.include?('-')
      start_age, end_age = window_period.split('-').map(&:to_i)
      (age >= start_age) && (age <= end_age) && (age >= milestone_days.to_i)
    else
      (age <= window_period.to_i) && (age >= milestone_days.to_i)
    end
  end
end