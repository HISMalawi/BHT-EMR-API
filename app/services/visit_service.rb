# rubocop:disable Metrics/MethodLength, Metrics/ClassLength, Metrics/AbcSize
# frozen_string_literal: true

# Visit Service
class VisitService 
    # visit_Number, patient first_name and patient_last_name, encounter_datetime patient_uuid
  
    # TODO: MOVE THIS AETC LOGIC TO ITS OWN SERVICE/ENGINE
  
    # AETC encounters
  
    INITIAL_REGISTRATION = 'Initial Registration'
    SCREENING = 'Screening'
    SOCICAL_HISTORY = 'SOCIAL HISTORY'
    FINANCING = 'Financing'
    REFERRAL = 'REFERRAL'
    VITALS = 'Vitals'
    PRESENTING_COMPLAINTS = 'PRESENTING COMPLAINTS'
    AIRWAY_ASSESSMENT = 'Airway Assessment'
    BLOOD_CIRCULATION = 'Blood Circulation'
    DISABILITY_ASSESSMENT = 'DISABILITY-ASSESSMENT'
    PERSISTENT_PAIN = 'Persistent Pain'
    TRIAGE_RESULT = 'Triage Result Observation'
  
    # AETC grouped encounters
  
    INITIAL_REGISTRATION_ENCOUNTERS = [INITIAL_REGISTRATION].freeze
    SCREENING_ENCOUNTERS = [SCREENING].freeze
    REGISTRATION_ENCOUNTERS = [SOCICAL_HISTORY, FINANCING, REFERRAL].freeze
    TRIAGE_ENCOUNTERS = [VITALS, PRESENTING_COMPLAINTS,
                         AIRWAY_ASSESSMENT, BLOOD_CIRCULATION, DISABILITY_ASSESSMENT,
                         PERSISTENT_PAIN].freeze
  
    # AETC screens to filter patients by group encounters completed
  
    SCREENS = {
      'screening' => INITIAL_REGISTRATION_ENCOUNTERS,
      'registration' => SCREENING_ENCOUNTERS,
      'triage' => REGISTRATION_ENCOUNTERS,
      'assessment' => TRIAGE_ENCOUNTERS
    }.freeze
  
    def self.visits_query(date: nil, open_visits_only: true, encounter_type_uuid: nil)
      encounter_type_condition = encounter_type_uuid ? "encounter_type.uuid = '#{encounter_type_uuid}'" : '1=1'
  
      people = Patient.joins(encounters: [:encounter_type, :visit, { person: [:names] }])
                      .joins('INNER JOIN users ON users.user_id = encounter.creator')
                      .joins('INNER JOIN person_name le ON le.person_id = users.person_id')
                      .where(visit: { visit_type: VisitType.where(name: 'OPD') })
                      .select(
                        'visit.patient_id',
                        'visit.uuid visit_uuid',
                        'GROUP_CONCAT(DISTINCT encounter_type.name) encounters_done',
                        'MIN(encounter.encounter_datetime) arrival_time',
                        'MAX(encounter.encounter_datetime) latest_encounter_time',
                        "MAX(CASE WHEN #{encounter_type_condition} THEN CONCAT(le.given_name, ' ',
                        le.family_name) ELSE NULL END) last_encounter_creator"
                      )
                      .group('visit.patient_id', 'visit.uuid')   
  
      people = people.where(visit: { date_started: date.beginning_of_day..date.end_of_day }) if date.present?
     # people = people.where(visit: { date_stopped: nil }) if open_visits_only
  
      people
        
    end
  
    def self.daily_visits(date: nil, category: nil, open_visits_only: true)      
      ActiveRecord::Base.transaction do
        patients = visits_query(date:, open_visits_only:)
        return patients if category.nil?
        patients.map do |patient|
          patient if eligible?(category, patient)
        end.compact
      end
    end
  
    def self.eligible?(category, patient)
      raise 'Invalid category' unless SCREENS.keys.include? category
  
      %i[all_previous_encounters_completed? next_encounters_incomplete?
         on_screening_for_less_than_24hrs?].all? do |method|
        send(method, category, patient)
      end
    end
  
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def self.find_visits(params)
      return daily_visits(category: params[:category]) if params.include? 'category'
  
      visits = Visit.all
      params.each do |key, value|
        next unless Visit.column_names.include? key
  
        if key.include? 'date'
          visits = visits.where("DATE(visit.#{key}) = ?", value&.to_date) unless value.nil? || value.empty?
          visits = visits.where(key => nil) if value.nil? || value.empty?
          next
        end
        visits = visits.where(key => value)
      end
      visits        
    end
  
    def self.create_visit(params)  
      

      person = Person.find_by(person_id: params[:patient]) 
     # program = Program.find_by(concept_id: params[:program])  
      visit_type = VisitType.find_by(uuid: params[:visit_type])         
      location = Location.find_by_uuid(params[:location]) if params[:location]
      #indication = ConceptName.find_by_name(params[:indication]) if params[:indication]
      #stop_datetime = params[:stop_datetime]
      start_datetime = params[:start_datetime]     
     # encounters = params.delete(:encounters)
      encounters = params[:encounters]  
     

  
    
      visit = Visit.new(     
        patient: person.patient,       
        visit_type: visit_type,     
        location: location,
       # indication: indication&.concept_id,
       # date_stopped: stop_datetime.presence,
        date_started: start_datetime   
      )

    visit.save!
           
      encounters&.each do |encounter|
        visit.add_encounter(Encounter.find_by_uuid(encounters))
      end
  
      # TODO: Generate visit number
      visit
    end
   
   
 
    def self.generate_visit_number
    # Close off hanging visits for the screening category
     # daily_visits(category: 'screening')
       
    # Fetch taken visit numbers for ongoing visits
    #  taken_visit_ids = Observation.joins(encounter: :visit).where(
    #    visit: { date_stopped: nil },
    #    obs: { concept_id: ConceptName.find_by_name('OPD Visit number').concept_id }
    #  ).pluck('obs.value_numeric')
      
      # Fetch taken visit numbers for ongoing visits using raw SQL query
      taken_visit_ids = ActiveRecord::Base.connection.execute("   
      SELECT `obs`.`value_numeric`
      FROM `obs`
      INNER JOIN `encounter` ON `encounter`.`voided` = 0 AND `encounter`.`encounter_id` = `obs`.`encounter_id`
      INNER JOIN `visit` ON `visit`.`voided` = FALSE AND `visit`.`visit_id` = `encounter`.`visit_id`
      WHERE `obs`.`voided` = 0 
      AND `visit`.`date_stopped` IS NULL 
      AND `obs`.`concept_id` = #{ConceptName.find_by_name('OPD Visit number').concept_id}
      ").map { |row| row['value_numeric'].to_f }
   

        
    # Start with visit number 1 and find the next available one
      visit_number = 1
      while taken_visit_ids.include?(visit_number) && not_assigned_today?(visit_number)
        visit_number += 1  
      # Optional safeguard: limit visit number to avoid infinite loop
        break if visit_number > 1000 # Adjust the limit as necessary
      end

      visit_number
    end



    def self.update_visit(visit_id, params)      
      
        
      visit = Visit.find_by(visit_id) 

      visit_type = VisitType.find_by_uuid(params[:visit_type])
      location = Location.find_by_uuid(params[:location]) if params[:location]       
      #indication = ConceptName.find_by_name(params[:indication]) if params[:indication]
      stop_datetime = params[:stop_datetime]
      start_datetime = params[:start_datetime]
      encounters = params.delete(:encounters)   
    
      
      visit.visit_type = visit_type if visit_type.present?
      visit.location = location if location.present?
     # visit.indication_concept_id = indication&.concept_id if indication.present?
      visit.date_stopped = stop_datetime if stop_datetime.present?
      visit.date_started = start_datetime if start_datetime.present?
      visit.save!
                   
       
      encounters&.each do |encounter|    
        visit.add_encounter(Encounter.find_by_uuid(encounter))
      end
  
      visit
    
    
    end
  
    private_class_method def self.all_previous_encounters_completed?(category, patient)
      SCREENS[category].all? { |encounter| patient.encounters_done.downcase.split(',').include? encounter.downcase }
    end
  
    private_class_method def self.next_encounters_incomplete?(category, patient)
      unless next_encounters(category).nil?
        return !(next_encounters(category).all? do |encounter|
          patient.encounters_done.downcase.split(',').include? encounter.downcase
        end)
      end
  
      true
    end
  
    private_class_method def self.on_screening_for_less_than_24hrs?(category, patient)
      # Skip this check if the category is not 'screening'
      # or if the patient has no open visit
      # if the patient's open visit was started more than 24 hours ago, close it
      # and return true
      # otherwise, return true
  
      return true unless category == 'screening'
  
      patient_open_visit = Visit.find_by(patient_id: patient.id, date_stopped: nil)
      initial_reg_encounter = Encounter.find_by(
        patient:,
        encounter_type: EncounterType.find_by_name(INITIAL_REGISTRATION)
      )
  
      return true if patient_open_visit.nil?
  
      if patient_open_visit.date_started < 24.hours.ago
  
        # create an observation for the reason the patient is being exited
           
        reason = Observation.new
        reason.person = patient.person
        reason.concept_id = ConceptName.find_by_name('Reason for exiting care').concept_id
        reason.value_text = 'Screening took more than 24 hours'
        reason.encounter = initial_reg_encounter
        reason.obs_datetime = Time.now
        reason.save!  
  
        # close the visit
        patient_open_visit.date_stopped = Time.now
        patient_open_visit.save!
  
        return false
      end
  
      true
    end
  
    private_class_method def self.next_encounters(category)
      SCREENS[next_category(category)]
    end
  
    private_class_method def self.next_category(category)
      keys = SCREENS.keys
      index = keys.index(category)
      return nil if index.nil? || index == keys.length - 1
  
      keys[index + 1]
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
  
  # rubocop:enable Metrics/ClassLength