
# frozen_string_literal: true

module ARTService
  module Reports

    encounter_names = [
      'VITALS','HIV STAGING',
      'APPOINTMENT','HIV CLINIC REGISTRATION',
      'ART_FOLLOWUP','LAB','TREATMENT','UPDATE OUTCOME',
      'HIV RECEPTION','HIV CLINIC CONSULTATION',
      'DISPENSING','LAB ORDERS','ART ADHERENCE',
      'GIVE LAB RESULTS','CERVICAL CANCER SCREENING',
      'HYPERTENSION MANAGEMENT','FAST TRACK ASSESMENT'
    ] 
     
    HIV_ENCOUNTERS = EncounterType.where('name IN(?)', encounter_names).map(&:id)  

    class AppointmentsReport
      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      def missed_appointments
        encounter_type = encounter_type 'APPOINTMENT'
        appointment_concept = concept 'Appointment date'
        program = Program.find_by_name 'HIV PROGRAM'

        encounter_ids = Encounter.where("encounter_type = ?
          AND encounter_datetime BETWEEN ? AND ?
          AND program_id = ?", encounter_type.id,
          @start_date.strftime('%Y-%m-%d 00:00:00'),
          @end_date.strftime('%Y-%m-%d 23:59:59'), 
          program.id).map(&:encounter_id) 

        encounter_ids = [0] if encounter_ids.blank?

        appointments = Observation.where("encounter_id IN(?)
          AND concept_id = ?", encounter_ids, appointment_concept.concept_id) 

        patients = []

        (appointments || []).each do |obs|
          missed = missed_appointment? obs
          patients << missed unless missed.blank?
        end

        return patients
      end


      private 

      def missed_appointment?(obs)
        client_came?(obs.person_id, obs.value_datetime)
      end

      def client_came?(person_id, value_datetime)
        encounters = Encounter.where("patient_id = ? AND encounter_type IN(?)
          AND encounter_datetime BETWEEN ? AND ?", person_id,
          HIV_ENCOUNTERS, value_datetime.to_date.strftime('%Y-%m-%d 00:00:00'),
          value_datetime.to_date.strftime('%Y-%m-%d 23:59:59'))        

        if encounters.blank?
          return client_info person_id, value_datetime
        end


      end

      def client_info(patient_id, appointment_date)
        person = ActiveRecord::Base.connection.select_one <<EOF
        SELECT  
          n.given_name, n.family_name, p.birthdate, p.gender,
          i.identifier arv_number, a.value cell_number,
          s.state_province district, s.county_district ta,
          s.city_village village
        FROM person p 
        LEFT JOIN person_name n ON n.person_id = p.person_id
        LEFT JOIN patient_identifier i ON i.patient_id = p.person_id
        AND i.voided = 0 AND i.identifier_type = 4 
        LEFT JOIN person_attribute a ON a.person_id = p.person_id
        AND a.voided = 0 AND a.person_attribute_type_id = 12
        LEFT JOIN person_address s ON s.person_id = p.person_id 
        AND s.voided = 0 WHERE p.person_id = #{patient_id} 
        GROUP BY p.person_id, DATE(p.date_created)
        ORDER BY p.person_id, p.date_created;
EOF

        return {
          given_name: person['given_name'],
          family_name: person['family_name'],
          birthdate: person['birthdate'],
          gender: person['gender'],
          cell_number: person['cell_number'],
          district: person['district'],
          ta: person['ta'],
          village: person['village'],
          arv_number: person['arv_number'],
          eventually_came_on: (eventually_came_on(patient_id, appointment_date)),
          appointment_date: appointment_date.to_date,
          person_id: patient_id
        }
      end

      def eventually_came_on(patient_id, date)
        data = ActiveRecord::Base.connection.select_one <<EOF
        SELECT MIN(encounter_datetime) visit_date FROM encounter
        WHERE patient_id = #{patient_id} 
        AND encounter_type IN(#{HIV_ENCOUNTERS.join(',')})
        AND encounter_datetime > '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}';
EOF

        return data['visit_date'].to_date rescue nil
      end

      def concept(name)
        ConceptName.find_by_name name
      end

      def encounter_type(name)
        EncounterType.find_by_name name
      end

    end
  end

end
