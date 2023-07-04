# frozen_string_literal: true

module ArtService
  module Reports
    # Produces an Appointment Report

    # rubocop:disable Metrics/ClassLength
    class AppointmentsReport
      ENCOUNTER_NAMES = [
        'VITALS', 'HIV STAGING',
        'APPOINTMENT', 'HIV CLINIC REGISTRATION',
        'ART_FOLLOWUP', 'TREATMENT', 'UPDATE OUTCOME',
        'HIV RECEPTION', 'LAB', 'HIV CLINIC CONSULTATION',
        'DISPENSING', 'LAB ORDERS', 'ART ADHERENCE',
        'GIVE LAB RESULTS', 'CERVICAL CANCER SCREENING',
        'HYPERTENSION MANAGEMENT', 'FAST TRACK ASSESMENT'
      ].freeze

      HIV_ENCOUNTERS = EncounterType.where('name IN(?)', ENCOUNTER_NAMES).map(&:id)

      def initialize(start_date:, end_date:)
        @start_date = start_date
        @end_date = end_date
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def missed_appointments
        appointments = Observation.joins(:encounter)
                                  .merge(appointment_encounters)
                                  .where.not(person_id: referral_patients.select(:person_id))
                                  .where(concept: ConceptName.where(name: 'Appointment date').select(:concept_id))
                                  .where('value_datetime BETWEEN ? AND ? AND encounter.program_id = ?',
                                         @start_date.strftime('%Y-%m-%d 00:00:00'),
                                         @end_date.strftime('%Y-%m-%d 23:59:59'), 1)
                                  .group(:person_id)

        appointments.each_with_object([]) do |appointment, patients|
          patient = missed_appointment?(appointment)

          patients << patient unless patient.blank?
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/CyclomaticComplexity
      def patient_visit_types
        yes_concept = ConceptName.find_by_name('YES').concept_id
        hiv_reception_breakdown = {}

        (patient_visits || []).each do |v|
          visit_date = v['obs_datetime'].to_date
          visit_type = v['name']
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

          if visit_type.match(/patient/i)
            hiv_reception_breakdown[visit_date][patient_id][:patient_present] = patient_present
          end
          if visit_type.match(/person/i)
            hiv_reception_breakdown[visit_date][patient_id][:guardian_present] = guardian_present
          end
        end

        hiv_reception_breakdown
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/PerceivedComplexity
      # rubocop:disable Metrics/CyclomaticComplexity
      def patient_visit_list
        yes_concept = ConceptName.find_by_name('YES').concept_id
        hiv_reception_breakdown = {}

        (patient_visits || []).each do |v|
          # visit_date = v['obs_datetime'].to_date
          visit_type = v['name']
          ans_given = v['value_coded'].to_i == yes_concept
          patient_id = v['patient_id'].to_i
          patient_present = (visit_type.match(/patient/i) && ans_given ? true : false)
          guardian_present = (visit_type.match(/person/i) && ans_given ? true : false)

          if hiv_reception_breakdown[patient_id].blank?
            demographics = client_data(patient_id)
            hiv_reception_breakdown[patient_id] = {
              patient_present: false, guardian_present: false,
              given_name: demographics['given_name'],
              family_name: demographics['family_name'],
              gender: demographics['gender'],
              birthdate: demographics['birthdate'],
              arv_number: demographics['arv_number']
            }
          end

          hiv_reception_breakdown[patient_id][:patient_present] = patient_present if visit_type.match(/patient/i)
          hiv_reception_breakdown[patient_id][:guardian_present] = guardian_present if visit_type.match(/person/i)
        end

        hiv_reception_breakdown
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      private

      def client_data(patient_id)
        ActiveRecord::Base.connection.select_one <<~SQL
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
        encounter_type = EncounterType.find_by_name('HIV RECEPTION')

        Observation.joins("INNER JOIN encounter e ON e.encounter_id = obs.encounter_id
          INNER JOIN concept_name c ON c.concept_id = obs.concept_id")\
                   .where('encounter_type = ? AND (obs_datetime BETWEEN ? AND ?)',
                          encounter_type.id, @start_date.strftime('%Y-%m-%d 00:00:00'),
                          @end_date.strftime('%Y-%m-%d 23:59:59'))\
                   .select("e.patient_id, obs.obs_datetime, c.name,
                  c.concept_id, obs.value_coded").group("DATE(obs.obs_datetime),
                     e.patient_id, c.concept_id").order('obs_datetime ASC')
      end

      def missed_appointment?(obs)
        client_came?(obs.person_id, obs.value_datetime, obs.encounter.encounter_datetime.to_date + 1.day)
      end

      def client_came?(person_id, value_datetime, day_after_visit_date)
        # we need to check if the client had a dispensing encounter
        # check if the client was given arv drugs via the orders table and drug_order table
        # on the drug_order table check if the quantity column is greater than 0
        # if the quantity is greater than 0 then the client was given drugs
        # arv drugs are easily found by Drug.arv_drugs
        encounters = Encounter.joins(:orders)
                              .joins("INNER JOIN drug_order d ON d.order_id = orders.order_id AND d.quantity > 0
                                      AND d.drug_inventory_id IN(#{arv_drugs})")
                              .where(patient_id: person_id, encounter_type: treatment_encounter)
                              .where('encounter_datetime BETWEEN ? AND ?',
                                     day_after_visit_date.strftime('%Y-%m-%d 00:00:00'),
                                     @end_date.strftime('%Y-%m-%d 23:59:59'))
                              .where(orders: { voided: 0 })
                              .where(voided: 0)

        client_info(person_id, value_datetime) if encounters.blank? && client_alive?(person_id, value_datetime)
      end

      def client_alive?(person_id, value_datetime)
        # check if the client is alive and doesn't have an adverse outcome
        result = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT patient_outcome(#{person_id}, '#{value_datetime.to_date}') outcome;
        SQL

        result['outcome'].match(/Patient died|Patient transferred out|Treatment stopped/i).blank?
      end

      def arv_drugs
        @arv_drugs ||= Drug.arv_drugs.pluck(:drug_id).join(',')
      end

      def treatment_encounter
        @treatment_encounter ||= EncounterType.find_by_name('TREATMENT').id
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def client_info(patient_id, appointment_date)
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

        current_outcome = get_current_outcome(patient_id)
        if current_outcome.match(/died/i) || current_outcome.match(/transfer/i) || current_outcome.match(/stop/i)
          return nil
        end

        {
          given_name: person['given_name'],
          family_name: person['family_name'],
          birthdate: person['birthdate'],
          gender: person['gender'],
          cell_number: person['cell_number'],
          district: person['district'],
          ta: person['ta'],
          village: person['village'],
          arv_number: (person['arv_number'].blank? ? 'N/A' : person['arv_number']),
          appointment_date: appointment_date.to_date,
          days_missed: days_missed(appointment_date.to_date),
          current_outcome: current_outcome,
          person_id: patient_id
        }
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      def days_missed(set_date)
        missed_days = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT TIMESTAMPDIFF(day, DATE('#{set_date}'), DATE('#{@end_date}')) days;
        SQL

        missed_days['days'].to_i
      end

      # rubocop:disable Metrics/MethodLength
      def eventually_came_on(patient_id, date)
        data = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT MIN(encounter_datetime) visit_date FROM encounter
          WHERE patient_id = #{patient_id}
          AND encounter_type IN(#{HIV_ENCOUNTERS.join(',')})
          AND encounter_datetime > '#{date.to_date.strftime('%Y-%m-%d 23:59:59')}';
        SQL

        begin
          data['visit_date'].to_date
        rescue StandardError
          nil
        end
      end
      # rubocop:enable Metrics/MethodLength

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

        current_outcome_info['outcome']
      end

      def referral_patients
        Observation.where(concept: ConceptName.where(name: 'Type of patient').select(:concept_id),
                          value_coded: ConceptName.where("name = 'External consultation' OR name = 'Drug refill'")
                                                  .select(:concept_id),
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
    # rubocop:enable Metrics/ClassLength
  end
end
