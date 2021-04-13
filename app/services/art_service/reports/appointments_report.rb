
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
        appointments = Observation.joins(:encounter)
                                  .merge(appointment_encounters)
                                  .where.not(person_id: referral_patients.select(:person_id))
                                  .where(concept: ConceptName.where(name: 'Appointment date').select(:concept_id))
                                  .where('value_datetime BETWEEN ? AND ?',
                                         @start_date.strftime('%Y-%m-%d 00:00:00'),
                                         @end_date.strftime('%Y-%m-%d 23:59:59'))
                                  .group(:person_id)

        appointments.each_with_object([]) do |appointment, patients|
          patient = missed_appointment?(appointment)

          patients << patient unless patient.blank?
        end
      end

      def patient_visit_types
        yes_concept = ConceptName.find_by_name("YES").concept_id
        hiv_reception_breakdown = {}

        (patient_visits || []).each do |v|
          visit_date = v['obs_datetime'].to_date
          visit_type = v["name"]
          ans_given = v['value_coded'].to_i == yes_concept
          patient_id = v['patient_id'].to_i
          patient_present = (visit_type.match(/patient/i) && ans_given ? true : false)
          guardian_present = (visit_type.match(/person/i) && ans_given ? true : false)

          if hiv_reception_breakdown[visit_date].blank?
            hiv_reception_breakdown[visit_date] = {}
            hiv_reception_breakdown[visit_date][patient_id] = {
              patient_present: 0, guardian_present: 0
            }
          elsif hiv_reception_breakdown[visit_date][patient_id].blank?
            hiv_reception_breakdown[visit_date][patient_id] = {
              patient_present: false, guardian_present: false
            }
          end

          hiv_reception_breakdown[visit_date][patient_id][:patient_present] = patient_present if visit_type.match(/patient/i)
          hiv_reception_breakdown[visit_date][patient_id][:guardian_present] = guardian_present if visit_type.match(/person/i)
        end


        return hiv_reception_breakdown
      end

      def patient_visit_list
        yes_concept = ConceptName.find_by_name("YES").concept_id
        hiv_reception_breakdown = {}

        (patient_visits || []).each do |v|
          visit_date = v['obs_datetime'].to_date
          visit_type = v["name"]
          ans_given = v['value_coded'].to_i == yes_concept
          patient_id = v['patient_id'].to_i
          patient_present = (visit_type.match(/patient/i) && ans_given ? true : false)
          guardian_present = (visit_type.match(/person/i) && ans_given ? true : false)

          if hiv_reception_breakdown[patient_id].blank?
            demographics = client_data(patient_id)
            hiv_reception_breakdown[patient_id] = {
              patient_present: false, guardian_present: false,
              given_name: demographics["given_name"],
              family_name: demographics["family_name"],
              gender: demographics["gender"],
              birthdate: demographics["birthdate"],
              arv_number: demographics["arv_number"]
            }
          end

          hiv_reception_breakdown[patient_id][:patient_present] = patient_present if visit_type.match(/patient/i)
          hiv_reception_breakdown[patient_id][:guardian_present] = guardian_present if visit_type.match(/person/i)
        end

        return hiv_reception_breakdown
      end

      private

      def client_data(patient_id)
        person = ActiveRecord::Base.connection.select_one <<~SQL
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
        SQL
      end

      def patient_visits
        encounter_type = EncounterType.find_by_name("HIV RECEPTION")

        observations = Observation.joins("INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
          INNER JOIN concept_name c ON c.concept_id = obs.concept_id").\
          where("encounter_type = ? AND (obs_datetime BETWEEN ? AND ?)",
            encounter_type.id, @start_date.strftime('%Y-%m-%d 00:00:00'),
              @end_date.strftime('%Y-%m-%d 23:59:59')).\
                select("e.patient_id, obs.obs_datetime, c.name,
                  c.concept_id, obs.value_coded").group("DATE(obs.obs_datetime),
                     e.patient_id, c.concept_id").order("obs_datetime ASC")

        return observations
      end


      def missed_appointment?(obs)
        client_came?(obs.person_id, obs.value_datetime)
      end

      def client_came?(person_id, value_datetime)
        encounters = Encounter.where("patient_id = ? AND encounter_type IN(?)
          AND encounter_datetime BETWEEN ? AND ?", person_id,
          HIV_ENCOUNTERS, (value_datetime.to_date - 14.day).strftime('%Y-%m-%d 00:00:00'),
          Date.today.strftime('%Y-%m-%d 23:59:59'))

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

        current_outcome = get_current_outcome(patient_id)
        return nil if current_outcome.match(/died/i) || current_outcome.match(/transfer/i) || current_outcome.match(/stop/i)

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
          appointment_date: appointment_date.to_date,
          days_missed: days_missed(appointment_date.to_date),
          current_outcome: current_outcome,
          person_id: patient_id
        }
      end

      def days_missed(set_date)
        missed_days  = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT TIMESTAMPDIFF(day, DATE('#{set_date}'), DATE('#{@end_date}')) days;
        SQL

        return missed_days["days"].to_i
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

      def get_current_outcome(patient_id)
        current_outcome_info = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_outcome(#{patient_id}, DATE('#{@end_date}')) as outcome;
        SQL

        return current_outcome_info['outcome']
      end

      def referral_patients
        Observation.where(concept: ConceptName.where(name: 'Type of patient').select(:concept_id),
                          value_coded: ConceptName.where(name: 'External consultation').select(:concept_id),
                          person_id: registration_encounters.select(:patient_id))
                   .where('obs_datetime < DATE(?) + INTERVAL 1 DAY', @end_date)
                   .distinct(:person_id)
      end

      def appointment_encounters
        Encounter.where(program: Program.where(name: 'HIV Program'),
                        type: EncounterType.where(name: 'Appointment'))
      end

      def registration_encounters
        Encounter.where(program: Program.where(name: 'HIV Program'),
                        type: EncounterType.where(name: 'Registration'))
      end
    end
  end
end
