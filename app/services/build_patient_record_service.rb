# frozen_string_literal: true

module BuildPatientRecordService
  class << self
    include ModelUtils
    def build_patient_record(patient_id)
      begin
        # Find the patient, handling potential not-found case
        record = Patient.find_by(patient_id: patient_id)
        return nil unless record

        # Get active programs for this patient
        active_programs = PatientProgram.where(patient_id: patient_id).to_a.map(&:as_json)

        # Safely access related data
        person = record.person
        name = person&.names&.first
        address = person&.addresses&.first

        {
          patientID: patient_id,
          ID: patient_identifier(record, 3),
          NcdID: patient_identifier(record, 31),
          program_id: '',
          provider_id: '',
          patient_identifiers: record.patient_identifiers.as_json,
          location_id: Encounter.where(patient_id: patient_id).order(encounter_datetime: :desc).first&.location_id,
          encounter_datetime: Encounter.where(patient_id: patient_id).order(encounter_datetime: :desc).first&.encounter_datetime,
          sync_status: '',
          personInformation: {
            given_name: name&.given_name || '',
            middle_name: name&.middle_name || '',
            family_name: name&.family_name || '',
            gender: person&.gender || '',
            birthdate: person&.birthdate&.to_s || '',
            birthdate_estimated: 'false',
            home_region: '',
            home_district: address&.address2 || '',
            home_traditional_authority: address&.county_district || '',
            home_village: address&.neighborhood_cell || '',
            current_region: '',
            current_district: address&.state_province || '',
            current_traditional_authority: address&.township_division || '',
            current_village: address&.city_village || '',
            country: address&.country || '',
            landmark: '',
            cell_phone_number: safe_get_attribute(record, 'Cell Phone Number'),
            occupation: safe_get_attribute(record, 'Occupation'),
            marital_status: safe_get_attribute(record, 'Civil Status'),
            religion: '',
            education_level: safe_get_attribute(record, 'EDUCATION LEVEL')
          },
          guardianInformation: {
            saved: safe_get_guardians(patient_id),
            unsaved: []
          },
          birthRegistration: safe_extract_observations(patient_id, safe_find_encounter_type('REGISTRATION')),
          otherPersonInformation: {
            nationalID: '',
            birthID: '',
            relationshipID: ''
          },
          vitals: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('VITALS')),
            unsaved: []
          },
          vaccineSchedule: safe_get_vaccine_schedule(person),
          vaccineAdministration: {
            orders: [],
            obs: [],
            voided: []
          },
          appointments: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('APPOINTMENT')),
            unsaved: []
          },
          diagnosis: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('DIAGNOSIS')),
            unsaved: []
          },
          screening: {
            saved: safe_get_screening_data(patient_id),
            unsaved: []
          },
          substanceAbuse: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('ASSESSMENT')),
            unsaved: []
          },
          labOrders: {
            saved: safe_get_lab_orders(patient_id),
            unsaved: [],
            voided: []
          },
          MedicationOrder: {
            saved: get_client_drug_orders(patient_id),
            unsaved: []
          },
          outCome: {
            saved: [],
            unsaved: []
          },
          notes: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('NOTES')),
            unsaved: []
          },
          allergies: {
            saved: safe_extract_observations(patient_id, safe_find_encounter_type('MEDICAL HISTORY')),
            unsaved: []
          },
          dispensations: {
            saved: PatientService.new.find_program_drug_orders_awaiting_dispensation(record, Date.today).as_json,
            unsaved: []
          },
          visits: safe_get_visits(record),
          saveStatusPersonInformation: '',
          saveStatusGuardianInformation: '',
          saveStatusBirthRegistration: '',
          activePrograms: active_programs
        }
      rescue StandardError => e
        Rails.logger.error("Error in build_patient_record for patient #{patient_id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        nil
      end
    end

    # Safe wrapper methods to prevent nil errors
    
    def safe_find_encounter_type(name)
      EncounterType.find_by_name(name)&.id
    rescue StandardError => e
      Rails.logger.error("Error finding encounter type '#{name}': #{e.message}")
      nil
    end
    
    def safe_get_screening_data(patient_id)
      begin
        screening_type = safe_find_encounter_type('SCREENING')
        return [] unless screening_type
        
        regular_screening = safe_extract_observations(patient_id, screening_type, nil, true) || []
        cvd_screening = safe_extract_observations(patient_id, screening_type, 
                                                { concept_id: safe_concept_name_to_id('CVD') }) || []
        
        [regular_screening + cvd_screening].flatten.compact
      rescue StandardError => e
        Rails.logger.error("Error getting screening data for patient #{patient_id}: #{e.message}")
        []
      end
    end
    
    def safe_concept_name_to_id(name)
      concept_name_to_id(name)
    rescue StandardError => e
      Rails.logger.error("Error converting concept name '#{name}' to ID: #{e.message}")
      nil
    end
    
    def safe_get_lab_orders(patient_id)
      begin
        return [] unless patient_id
        Lab::OrdersSearchService.find_orders(patient_id: patient_id)
      rescue StandardError => e
        Rails.logger.error("Error getting lab orders for patient #{patient_id}: #{e.message}")
        []
      end
    end
    
    def safe_get_vaccine_schedule(person)
      begin
        return [] unless person
        ImmunizationService::VaccineScheduleService.vaccine_schedule(person)
      rescue StandardError => e
        Rails.logger.error("Error getting vaccine schedule: #{e.message}")
        []
      end
    end
    
    def safe_get_visits(record)
      begin
        {
          visitsDates: visits(record) || [],
          NCDVisitsDates: visits(record, 32) || [],
          OPDVisitsDates: visits(record, 14) || []
        }
      rescue StandardError => e
        Rails.logger.error("Error getting visits for patient: #{e.message}")
        { visitsDates: [], NCDVisitsDates: [], OPDVisitsDates: [] }
      end
    end

    def visits(record, program_id = nil)
      return [] unless record
      
      begin
        program = program_id ? Program.find_by(program_id: program_id) : nil
        patient_service.find_patient_visit_dates(record, program)
      rescue StandardError => e
        Rails.logger.error("Error in visits method: #{e.message}")
        []
      end
    end
    
    def safe_get_attribute(item, name)
      return '' unless item&.person
      
      begin
        attribute = item.person.person_attributes.find { |attr| attr.type.name == name }
        attribute&.value || ''
      rescue StandardError => e
        Rails.logger.error("Error getting attribute '#{name}': #{e.message}")
        ''
      end
    end

    def patient_identifier(identifiers, identifier_type_id)
      begin
        if identifiers
          identifiers.patient_identifiers
                    .select { |identifier| identifier.identifier_type == identifier_type_id }
                    .map(&:identifier)
                    .join(', ')
        else
          ''
        end
      rescue StandardError => e
        Rails.logger.error("Error getting patient identifier for type #{identifier_type_id}: #{e.message}")
        ''
      end
    end

    def safe_get_guardians(patient_id)
      begin
        return [] unless patient_id
        
        person = Person.find_by(person_id: patient_id)
        return [] unless person
        
        relationships_service = PersonRelationshipService.new(person)
        relationships = relationships_service.find_relationships('')
        return [] unless relationships.is_a?(Enumerable) && relationships.any?

        relationships.map do |relationship|
          build_guardian_hash(relationship)
        end.compact
      rescue StandardError => e
        Rails.logger.error("Error getting guardians for patient #{patient_id}: #{e.message}")
        []
      end
    end
    
    def build_guardian_hash(relationship)
      return nil unless relationship
      
      begin
        person = relationship.relation
        return nil unless person
        
        name = person.names&.first
        address = person.addresses&.first

        {
          given_name: name&.given_name || '',
          middle_name: name&.middle_name || '',
          family_name: name&.family_name || '',
          gender: person&.gender || '',
          birthdate: person&.birthdate&.to_s || '',
          birthdate_estimated: person&.birthdate_estimated&.to_s || '',

          home_region: address&.region || '',
          home_district: address&.county_district || '',
          home_traditional_authority: address&.township_division || '',
          home_village: address&.city_village || '',

          current_region: address&.region || '',
          current_district: address&.county_district || '',
          current_traditional_authority: address&.township_division || '',
          current_village: address&.city_village || '',

          landmark: safe_get_person_attribute(person, 'Landmark Or Plot Number'),
          cell_phone_number: safe_get_person_attribute(person, 'Cell Phone Number'),
          national_id: '',

          relationship_id: relationship.id.to_s || '',
          relationship_type: {
            a_is_to_b: relationship.type&.a_is_to_b || '',
            b_is_to_a: relationship.type&.b_is_to_a || '',
            relationship_type_id: relationship.type&.id&.to_s || ''
          }
        }
      rescue StandardError => e
        Rails.logger.error("Error building guardian hash: #{e.message}")
        nil
      end
    end
    
    def safe_get_person_attribute(person, attribute_name)
      return '' unless person&.person_attributes
      
      begin
        attribute = person.person_attributes.find { |attr| attr.type.name == attribute_name }
        attribute ? attribute.value : ''
      rescue StandardError => e
        Rails.logger.error("Error getting person attribute '#{attribute_name}': #{e.message}")
        ''
      end
    end

    def safe_extract_observations(patient_id, encounter_type, value_filters = nil, has_children = nil)
      begin
        return [] unless patient_id && encounter_type
        
        encounters = Encounter.where(patient_id: patient_id, encounter_type: encounter_type)
        return [] unless encounters.any?

        encounters.flat_map do |encounter|
          safe_process_observations(encounter, value_filters, has_children)
        end.compact
      rescue StandardError => e
        Rails.logger.error("Error extracting observations for patient #{patient_id}, encounter type #{encounter_type}: #{e.message}")
        []
      end
    end
    
    def safe_process_observations(encounter, value_filters, has_children)
      begin
        encounter.observations
                .select do |observation|
                  if value_filters
                    safe_matches_filters?(observation, value_filters)
                  else
                    !has_children || observation.children.length.positive?
                  end
                end
                .map do |observation|
          safe_build_observation_hash(observation, encounter)
        end.compact
      rescue StandardError => e
        Rails.logger.error("Error processing observations for encounter #{encounter.id}: #{e.message}")
        []
      end
    end
    
    def safe_build_observation_hash(observation, encounter)
      begin
        children = observation.children.map { |child| safe_build_observation_hash(child, encounter) }
    
        {
          concept_id: observation.concept_id,
          concept_name: safe_concept_id_to_name(observation.concept_id),
          obs_datetime: observation.obs_datetime&.to_s,
          obs_id: observation.obs_id,
          children: children,
          value_coded: observation.value_coded,
          value_text: observation.value_text || '',
          value_numeric: observation.value_numeric,
          provider_id: encounter.provider_id,
          location_id: encounter.location_id,
          program_id: encounter.program_id,
        }
      rescue StandardError => e
        Rails.logger.error("Error building observation hash for obs #{observation.id}: #{e.message}")
        nil
      end
    end
    
    def safe_concept_id_to_name(concept_id)
      begin
        return '' unless concept_id
        concept_id_to_name(concept_id)
      rescue StandardError => e
        Rails.logger.error("Error converting concept ID #{concept_id} to name: #{e.message}")
        ''
      end
    end

    def get_client_drug_orders(patient_id)
      begin
        return [] if patient_id.nil? || patient_id.to_s.strip.empty?
        
        begin
          results = DrugOrderService.fetch_all_patient_drug_orders(patient_id)
          return results unless results.empty?
        rescue => e
          Rails.logger.error("Inner error fetching drug orders for patient #{patient_id}: #{e.message}")
        end
        
        []
      rescue => e
        Rails.logger.error("Outer error fetching drug orders for patient #{patient_id}: #{e.message}")
        []
      end
    end
    
    def patient_service
      PatientService.new
    end
    
    def safe_matches_filters?(observation, filters)
      begin
        return true if filters.nil? || filters.empty?

        filters.any? do |field, value|
          observation.respond_to?(field) && observation.send(field) == value
        end
      rescue StandardError => e
        Rails.logger.error("Error matching filters: #{e.message}")
        false
      end
    end
  end
end