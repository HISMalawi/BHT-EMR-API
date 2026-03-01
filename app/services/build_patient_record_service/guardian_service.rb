# frozen_string_literal: true
module BuildPatientRecordService
  module GuardianService
    def safe_get_guardians(patient_id)
      begin
        return [] unless patient_id
        
        person = Person.find_by(person_id: patient_id)
        return [] unless person
        
        relationships_service = PersonRelationshipService.new(person)
        relationships = relationships_service.find_relationships('')
        return [] unless relationships.is_a?(Enumerable) && relationships.any?

        relationships.map do |relationship|
          build_guardian_hash(relationship, patient_id)
        end.compact
      rescue StandardError => e
        Rails.logger.error("Error getting guardians for patient #{patient_id}: #{e.message}")
        []
      end
    end
    
    private

    def build_guardian_hash(relationship, patient_id)
      return nil unless relationship
      
      begin
        # Determine if patient is person_a or person_b
        patient_is_person_a = relationship.person_a == patient_id
        
        # Get the guardian (the other person in the relationship)
        person = patient_is_person_a ? relationship.relation : relationship.person
        return nil unless person
        
        # Get the correct relationship type label
        # If patient is person_a: use a_is_to_b (patient is X to guardian)
        # If patient is person_b: use b_is_to_a (patient is X to guardian)
        relationship_to_patient = patient_is_person_a ? 
                                   relationship.type&.b_is_to_a : 
                                   relationship.type&.a_is_to_b
        
        relationship_from_patient = patient_is_person_a ? 
                                     relationship.type&.a_is_to_b : 
                                     relationship.type&.b_is_to_a
        
        name = person.names&.first
        address = person.addresses&.first

        patient = Patient.find_by_patient_id(person.person_id)

        identifier =  if patient.present?
                        BuildPatientRecordService::PatientIdentifierService.patient_identifier(patient, 3)
                      end

        {
          ID: identifier || '',
          person_id: person.person_id.to_s || '',
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
          national_id: safe_get_person_attribute(person, 'Guardian ID'),

          relationship_id: relationship.id.to_s || '',
          relationship_type: {
            # What the guardian is to the patient (e.g., "Mother", "Father")
            guardian_is_to_patient: relationship_to_patient || '',
            # What the patient is to the guardian (e.g., "Child", "Daughter")
            patient_is_to_guardian: relationship_from_patient || '',
            # Original relationship type fields
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
  end
end