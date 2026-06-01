# frozen_string_literal: true
require 'securerandom'

print "Booting ML Profile Generator... "

# Safely initialize the environment context required by MAHIS modules
User.current = User.first || User.new(user_id: 1)
Location.current = Location.first || Location.new(location_id: 1)

hiv_program = Program.find_by_name('HIV PROGRAM')
if hiv_program.nil?
  puts "ERROR: 'HIV PROGRAM' not found. Ensure MAHIS is seeded."
  exit 1
end

# Extract concept maps needed for robust evaluation mapping
malaria_concept = ConceptName.find_by_name('Malaria severity')&.concept_id
mental_concept = ConceptName.find_by_name('Mental status')&.concept_id

defaulted_concept = Concept.joins(:concept_names).where(concept_name: { name: 'Patient defaulted' }).first
default_state_id = ProgramWorkflowState.find_by_concept_id(defaulted_concept&.id)&.id

if default_state_id.nil?
  puts "ERROR: 'Patient defaulted' state concept mapping not accessible!"
  exit 1
end

num_patients = 200
puts "[OK]"
puts "Generating #{num_patients} patients across OpenMRS EAV tables. This injects thousands of records..."

ActiveRecord::Base.transaction do
  num_patients.times do |i|
    # ==========================
    # 1. Demographics Setup
    # ==========================
    gender = ['M', 'F'].sample
    birthdate = rand(18..65).years.ago.to_date
    person = Person.create!(gender: gender, birthdate: birthdate)
    first_names = ["John", "Mary", "Peter", "Susan", "Paul", "Alice", "James", "Sarah", "Blessings", "Gift", "Grace", "Memory"]
    last_names = ["Banda", "Phiri", "Mwale", "Tembo", "Nyirenda", "Chirwa", "Lungu", "Ngwira", "Zimba", "Gama", "Soko", "Phakati"]
    PersonName.create!(person_id: person.id, given_name: first_names.sample, family_name: last_names.sample)
    
    patient = Patient.create!(patient_id: person.id)
    
    # Optionally attach a mock identifier natively
    PatientIdentifier.create!(
      patient_id: patient.id, 
      identifier: "ML#{SecureRandom.random_number(100000..999999)}", 
      identifier_type: 3, 
      location_id: Location.current.location_id
    )

    # ==========================
    # 2. Program Enrollment
    # ==========================
    program_start = rand(10..36).months.ago.to_date
    patient_program = PatientProgram.create!(
      patient_id: patient.id, 
      program_id: hiv_program.id, 
      date_enrolled: program_start,
      location_id: Location.current.location_id
    )
    
    # ==========================
    # 3. Clinical Trajectories
    # ==========================
    num_encounters = rand(3..15)
    num_encounters.times do |offset|
      visit_date = program_start + (offset * rand(20..40)).days # Creates a roughly monthly trajectory
      break if visit_date > Date.today
      
      enc = Encounter.new(
        patient_id: patient.id, 
        encounter_type: 7, # Mock general encounter type
        encounter_datetime: visit_date, 
        program_id: hiv_program.id,
        location_id: Location.current.location_id,
        provider_id: User.current.person_id
      )
      enc.save(validate: false)
      
      
      # Inject Side Effects via Native Observation API Concept
      if malaria_concept && rand < 0.25
        obs1 = Observation.new(person_id: person.id, encounter_id: enc.id, obs_datetime: visit_date, concept_id: malaria_concept, value_numeric: rand(1..3))
        obs1.save(validate: false)
      end
      
      # Inject Psychological markers via Observation
      if mental_concept && rand < 0.15
        obs2 = Observation.new(person_id: person.id, encounter_id: enc.id, obs_datetime: visit_date, concept_id: mental_concept, value_numeric: 1)
        obs2.save(validate: false)
      end
    end
    
    # ==========================
    # 4. Medication Loads
    # ==========================
    num_enc = Encounters = Encounter.where(patient_id: patient.id).pluck(:encounter_id)
    if num_enc.any?
        rand(1..4).times do 
          mock_order = Order.new(
            patient_id: patient.id, 
            order_type_id: 1, # Drug order mapping
            concept_id: 1, # Mock concept just for DB integrity
            encounter_id: num_enc.sample,
            orderer: User.current.user_id,
            start_date: program_start,
            auto_expire_date: program_start + 30.days
          )
          mock_order.save(validate: false)
        end
    end
    
    # ==========================
    # 5. Cohort Resolutions!
    # ==========================
    if rand < 0.35 # Assign ~35% failure rate to simulate Defaulted cases for ML
      ps = PatientState.new(
        patient_program_id: patient_program.id, 
        state: default_state_id, 
        start_date: rand(1..5).months.ago.to_date
      )
      ps.save(validate: false)
    else
        # Force an "On ARV" normal state to train against
        on_art_state = ProgramWorkflowState.joins(:concept).merge(Concept.joins(:concept_names).where(concept_name: { name: 'On antiretrovirals' })).first&.id
        if on_art_state
             ps2 = PatientState.new(
                patient_program_id: patient_program.id, 
                state: on_art_state, 
                start_date: program_start
              )
             ps2.save(validate: false)
        end
    end
    
    print "." if (i % 10).zero?
  end
end

puts "\n\nML Patient Schema Expansion Complete! Successfully pushed thousands of rows establishing 200 Deep-linked simulated patients."
