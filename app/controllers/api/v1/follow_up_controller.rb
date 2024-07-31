class Api::V1::FollowUpController < ApplicationController
  before_action :initialize_variables, only: [:vaccine_milestones]

  def vaccine_milestones
    begin
      milestones = get_milestones_with_vaccine

      @data = milestones.map do |milestone|
        drugs = milestone[:drugs].map do |drug|
          missed_patients = patients_who_missed_vaccine(drug[:drug_id], milestone[:milestone])
          { drug_name: drug[:drug_name], missed_patients: missed_patients }
        end
        { milestone: milestone[:milestone], drugs: drugs }
      end

      render json: @data, status: :ok
    rescue StandardError => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  private

  def initialize_variables

    #here when the user is mapped to location replace 265 with current user location
   @patients = Observation.where(location_id: 265,voided:0)
               .group(:person_id)
               .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type = #{EncounterType.find_by_name('IMMUNIZATION RECORD').id}")
               .joins("INNER JOIN person ON person.person_id = obs.person_id")
               .joins("INNER JOIN person_name ON person_name.person_id = obs.person_id")
               .where(encounter: { program_id: 33 ,voided: 0})
               .select("obs.person_id AS person_id, person.birthdate AS birthdate, person.gender AS gender,
                       person_name.given_name AS firstname, person_name.family_name AS sirname")
               .map do |patient|
                 {
                   person_id: patient.person_id,
                   firstname: patient.firstname,
                   sirname: patient.sirname,
                   dob: patient.birthdate,
                   gender: patient.gender
                 }
               end
  end

  def get_milestones_with_vaccine
    ConceptSet.joins("INNER JOIN concept_name s ON s.concept_id = concept_set.concept_id AND concept_set.concept_set = #{ConceptName.find_by(name: 'Immunizations').concept_id}")
              .select("s.name AS milestone, s.concept_id")
              .map do |set|
                drugs = Drug.where(concept_id: set.concept_id).select(:drug_id, :name)
                { milestone: set.milestone, drugs: drugs.map { |drug| { drug_id: drug.drug_id, drug_name: drug.name } } }
              end
  end

  def patients_who_missed_vaccine(drug_id, milestone)
    scheduled_patients_ids = []

    @patients.each do |patient|
      if patient[:gender] == 'M' || patient[:gender] == 'Male'
        female_only_drugs = check_immunization_gender
        next if female_only_drugs.include?(drug_id)
      end

      patient_id = validate_with_age(milestone, patient[:dob])

      unless patient_id.nil?
        result = Observation.where(person_id: patient_id,voided:0)
                            .joins("INNER JOIN encounter ON encounter.encounter_id = obs.encounter_id AND encounter.encounter_type = #{EncounterType.find_by_name('IMMUNIZATION RECORD').id}")
                            .joins("INNER JOIN orders ON orders.encounter_id = obs.encounter_id AND orders.order_id = obs.order_id")
                            .joins("INNER JOIN drug_order ON drug_order.order_id = orders.order_id")
                            .where(encounter: { program_id: 33,voided: 0}, drug_order: { drug_inventory_id: drug_id },orders: { voided: 0 })
                            .count

        scheduled_patients_ids.push(patient) if result == 0
      end
    end

    scheduled_patients_ids
  end

  def check_immunization_gender
    ConceptSet.joins("INNER JOIN concept_name s ON s.concept_id = concept_set.concept_id AND concept_set.concept_set = #{ConceptName.find_by(name: 'Female only Immunizations').concept_id}")
              .select("concept_set.concept_id")
              .flat_map do |set|
                Drug.where(concept_id: set.concept_id).pluck(:drug_id)
              end
  end

  def validate_with_age(milestone, birthdate)
    return nil if birthdate.blank?

    age_in_days = (Date.today - birthdate).to_i

    case milestone
    when 'At birth'
      age_in_days < 7 ? birthdate : nil
    when '6 weeks'
      age_in_days >= 42 && age_in_days < 56 ? birthdate : nil
    when '10 weeks'
      age_in_days >= 70 && age_in_days < 84 ? birthdate : nil
    when '14 weeks'
      age_in_days >= 98 && age_in_days < 112 ? birthdate : nil
    when '5 months'
      age_in_days >= 150 && age_in_days < 180 ? birthdate : nil
    when '6 months'
      age_in_days >= 180 && age_in_days < 210 ? birthdate : nil
    when '7 months'
      age_in_days >= 210 && age_in_days < 240 ? birthdate : nil
    when '8 months'
      age_in_days >= 240 && age_in_days < 270 ? birthdate : nil
    when '9 months'
      age_in_days >= 270 && age_in_days < 300 ? birthdate : nil
    when '15 months'
      age_in_days >= 450 && age_in_days < 480 ? birthdate : nil
    when '22 months'
      age_in_days >= 660 && age_in_days < 690 ? birthdate : nil
    when '9 years'
      age_in_days >= 3285 && age_in_days < 3315 ? birthdate : nil
    when '12 years above'
      age_in_days >= 4380 && age_in_days < 5475 ? birthdate : nil
    when '15 years'
      age_in_days >= 5475 && age_in_days < 5840 ? birthdate : nil
    when '18 years above'
      age_in_days >= 6570 ? birthdate : nil
    else
      nil
    end
  end
end
