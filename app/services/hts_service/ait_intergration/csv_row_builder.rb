module HTSService::AITIntergration
    class CsvRowBuilder

      AIT_CONFIG = YAML.load_file("#{Rails.root}/config/ait.yml")

      def caseid patient
        nil
      end

      def name patient
        patient.name
      end

      def first_name patient
        patient.person.names.first.given_name
      end

      def last_name patient
        patient.person.names.first.family_name
      end

      def client_patient_id patient
        patient.patient_id
      end

      def dob_known patient
        patient.person.birthdate_estimated == 0 ? 'Yes' : 'No'
      end

      def age_format patient
        "Years"
      end

      def sex_dissagregated patient
        patient.gender
      end

      def marital_status patient
        observation_answer patient, "Civil status"
      end

      def phone_number patient
        PersonAttribute.where(person_id: patient.patient_id, person_attribute_type_id: [12,14,15]).last.value rescue nil
      end

      def entry_point patient
        observation_answer patient, "Location where test took place"
      end

      def consent patient
       1
      end

      def consent_refusal_reason patient
        nil
      end

      def index_comments patient
        nil
      end

      def age_in_years patient
        patient.age
      end

      def age_in_months patient
        patient.age_in_months
      end

      def age patient
        patient.age
      end

      def index_interview_date patient
        patient.encounters.last.encounter_datetime.to_date
      end

      def age_group patient
        case patient.age
        when 0..14
          "0-14 Years"
        when 15..24
          "15-24 Years"
        when 25..29
          "25-29 Years"
        when 30..Float::INFINITY
          "29+ Years"
        end
      end

      def dob patient
        patient.person.birthdate
      end

      def index_client_category patient
        observation_answer patient, "HIV group"
      end

      def sex patient
        patient.gender
      end

      def generation patient
        1
      end

      def close_case_date patient
        nil
      end

      def registered_by patient
        User.current.username
      end

      def closed_contacts patient
        0
      end

      def enlisted_contacts patient
        observation(patient, "Firstnames of contact").count
      end

      def eligible_t_contacts patient
        observation(patient, "Contact HIV tested").select{|o| o.value_coded == 703}.count
      end

      def reached_contacts patient
        0
      end

      def tested_contacts patient
        observation(patient, "Contact has had HIV testing").select{|o| o.value_coded == 1065}.count
      end

      def eligible_ait_contacts patient
        enlisted_contacts patient
      end

      def index_client_id patient
        patient.id
      end

      def health_facility_id patient
        AIT_CONFIG['health_facility_id']
      end

      def health_facility_name patient
        AIT_CONFIG['health_facility_name']
      end

      def district_id patient
        AIT_CONFIG['district_id']
      end

      def district_name patient
        AIT_CONFIG['district_name']
      end

      def region_id patient
        AIT_CONFIG['region_id']
      end

      def region_name patient
        AIT_CONFIG['region_name']
      end

      def partner patient
        AIT_CONFIG['partner']
      end

      def owner_id patient
        health_facility_id patient
      end

      def site_id patient
        AIT_CONFIG['site_id']
      end

      def dhis2_code patient
        AIT_CONFIG['dhis2_code']
      end

      def continue_registration patient
        1
      end

      def hiv_status patient
        observation_answer patient, "HIV status"
      end

      def import_validation patients
        1
      end

      def index_entry_point patients
        entry_point patients
      end

      def observation_answer patient, concept_name
        Observation
          .where(person_id: patient.patient_id, concept_id: ConceptName.find_by_name(concept_name).concept_id)
          .last.answer_string rescue nil
      end

      def observation patient, concept
        Observation
          .where(
            person_id: patient.patient_id,
            concept_id: ConceptName.find_by_name(concept).concept_id
          )
      end
  end
end