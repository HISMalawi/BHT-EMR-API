# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ##
      # Patients who started TPT just before the start of the current
      # and have finished within the current reporting period.
      class TbPrev3
        attr_reader :start_date, :end_date, :check_date, :cut_off_point

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = ActiveRecord::Base.connection.quote(start_date)
          @check_date = start_date.to_date - 6.months
          @cut_off_point = start_date.to_date
          @end_date = ActiveRecord::Base.connection.quote(end_date)
        end

        def find_report
          report = init_report
          patients = group_patients_by_tpt_course(patients_on_tpt)

          load_patients_into_report(report, patients.six_h, '6H') do |patient|
            # 6H has a constant dosage of 1 pill per day
            patient_completed_tpt?(patient, '6H')
          end

          load_patients_into_report(report, patients.three_hp, '3HP') do |patient|
            # 3HP daily dosages vary by patient weight can't use easily use pills
            # to determine course completion
            patient_completed_tpt?(patient, '3HP')
          end

          report
        end

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/PerceivedComplexity
        def patient_tpt_status(patient_id)
          return { tpt: nil, completed: false, tb_treatment: true } if patient_on_tb_treatment?(patient_id)

          if patient_history_on_completed_tpt(patient_id)
            return { tpt: patient_history_on_completed_tpt(patient_id).include?('IPT') ? '6H' : '3HP', completed: true,
                     tb_treatment: false }
          end

          patient = individual_tpt_report(patient_id)
          return { tpt: nil, completed: false, tb_treatment: false } if patient.blank?

          tpt = patient_on_3hp?(patient) ? '3HP' : '6H'
          completed = patient_completed_tpt?(patient, tpt)
          { tpt: if tpt == '6H'
                   'IPT'
                 else
                   (patient['drug_concepts'].split(',').length > 1 ? '3HP (RFP + INH)' : 'INH 300 / RFP 300 (3HP)')
                 end, completed: completed, tb_treatment: false }
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity

        def fetch_individual_report(patient_id)
          individual_tpt_report(patient_id)
        end

        private

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = %w[M F Unknown].each_with_object({}) do |gender, gender_sub_report|
              gender_sub_report[gender] = %w[6H 3HP].each_with_object({}) do |tpt, tpt_sub_report|
                tpt_sub_report[tpt] = {
                  started_new_on_art: [],
                  started_previously_on_art: [],
                  completed_new_on_art: [],
                  completed_previously_on_art: []
                }
              end
            end
          end
        end

        def load_patients_into_report(report, patients, tpt, &patient_has_completed_tpt)
          patients.each do |patient|
            next if patient['transfer_in'] == 1 && !patient_has_completed_tpt[patient]

            age_group = patient['age_group']
            gender = patient['gender']&.first&.upcase || 'Unknown'
            tpt_states = find_patient_tpt_state(patient, &patient_has_completed_tpt)

            tpt_states.each do |tpt_state|
              report[age_group][gender][tpt][tpt_state] << patient
            end
          end
        end

        def find_patient_tpt_state(patient, &patient_has_completed_tpt)
          if patient_has_completed_tpt[patient]
            return %i[completed_new_on_art] if patient_new_on_art?(patient) && patient['transfer_in'] == 1

            return %i[started_new_on_art completed_new_on_art] if patient_new_on_art?(patient)

            return %i[completed_previously_on_art] if patient['transfer_in'] == 1

            return %i[started_previously_on_art completed_previously_on_art]
          end

          return %i[started_new_on_art] if patient_new_on_art?(patient)

          %i[started_previously_on_art]
        end

        def patient_new_on_art?(patient)
          tpt_initiation_date = patient['tpt_initiation_date'].to_date
          art_start_date = patient['art_start_date'].to_date

          (tpt_initiation_date >= art_start_date) && (tpt_initiation_date < art_start_date + 180.days)
        end

        def patients_on_tpt
          clients = fetch_patients_on_tpt.to_a
          results = []
          clients.each do |client|
            next if client['tpt_initiation_date'].to_date > cut_off_point

            result = individual_tpt_report(client['patient_id'])
            next if result.blank?
            next if result['tpt_initiation_date'].to_date < check_date

            client['tpt_initiation_date'] = result['tpt_initiation_date']
            client['total_pills_taken'] = result['total_pills_taken']
            client['months_on_tpt'] = result['months_on_tpt']
            client['total_days_on_medication'] = result['total_days_on_medication']
            client['drug_concepts'] = result['drug_concepts']
            client['transfer_in'] = result['transfer_in']
            results << client
          end
          results
        end

        def fetch_patients_on_tpt
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT person.person_id AS patient_id,
                   patient_identifier.identifier AS arv_number,
                   DATE(MIN(orders.start_date)) AS tpt_initiation_date,
                   date_antiretrovirals_started(person.person_id, MIN(denominator_patient.start_date)) AS art_start_date,
                   patient_outcome(person.person_id, DATE(#{end_date})) AS outcome,
                   person.gender,
                   person.birthdate,
                   disaggregated_age_group(person.birthdate, DATE(#{end_date})) AS age_group
            FROM person
            LEFT JOIN patient_identifier
              ON patient_identifier.patient_id = person.person_id
              AND patient_identifier.voided = 0
              AND patient_identifier.identifier_type IN (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'ARV Number')
            INNER JOIN(
                SELECT denominator_encounter.patient_id AS patient_id, patient_state.start_date AS start_date
                FROM person
                INNER JOIN patient_program
                  ON patient_program.patient_id = person.person_id
                  AND patient_program.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND patient_program.voided = 0
                INNER JOIN patient_state
                  ON patient_state.patient_program_id = patient_program.patient_program_id
                  AND patient_state.state = 7 /* State: 7 == On antiretrovirals */
                  AND patient_state.start_date < DATE(#{start_date})
                  AND patient_state.voided = 0
                INNER JOIN encounter AS denominator_encounter
                  ON denominator_encounter.patient_id = patient_program.patient_id
                  AND denominator_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
                  AND denominator_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
                  AND denominator_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
                  AND denominator_encounter.encounter_datetime <= DATE(#{start_date})
                  AND denominator_encounter.voided = 0
                GROUP BY patient_id
            ) AS denominator_patient ON denominator_patient.patient_id = person.person_id
            INNER JOIN encounter AS prescription_encounter
              ON prescription_encounter.patient_id = denominator_patient.patient_id
              AND prescription_encounter.program_id IN (SELECT program_id FROM program WHERE name = 'HIV Program')
              AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'Treatment')
              AND prescription_encounter.encounter_datetime >= DATE(#{start_date}) - INTERVAL 6 MONTH
              AND prescription_encounter.encounter_datetime <= DATE(#{end_date})
              AND prescription_encounter.voided = 0
            INNER JOIN orders
              ON orders.encounter_id = prescription_encounter.encounter_id
              AND orders.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND orders.start_date >= DATE(#{start_date}) - INTERVAL 6 MONTH
              AND orders.start_date <= DATE(#{end_date})
              AND orders.voided = 0
            INNER JOIN concept_name
              ON concept_name.concept_id = orders.concept_id
              AND concept_name.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')
            INNER JOIN drug_order
              ON drug_order.order_id = orders.order_id
              AND drug_order.quantity > 0
            WHERE person.voided = 0
              AND person.person_id NOT IN (
              /* External consultations */
              SELECT DISTINCT registration_encounter.patient_id
              FROM patient_program pp
              INNER JOIN program p ON p.program_id = pp.program_id AND p.name = 'HIV Program' AND p.retired = 0
              INNER JOIN encounter AS registration_encounter
                ON registration_encounter.patient_id = pp.patient_id
                AND registration_encounter.program_id = pp.program_id
                AND registration_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
                AND registration_encounter.voided = 0
              INNER JOIN (
                SELECT MAX(encounter.encounter_datetime) AS encounter_datetime, encounter.patient_id
                FROM encounter
                INNER JOIN encounter_type
                  ON encounter_type.encounter_type_id = encounter.encounter_type
                  AND encounter_type.name = 'Registration'
                INNER JOIN program
                  ON program.program_id = encounter.program_id
                  AND program.name = 'HIV Program'
                WHERE encounter.encounter_datetime < DATE(#{end_date}) AND encounter.voided = 0
                GROUP BY encounter.patient_id
              ) AS max_registration_encounter
                ON max_registration_encounter.patient_id = registration_encounter.patient_id
                AND max_registration_encounter.encounter_datetime = registration_encounter.encounter_datetime
              INNER JOIN obs AS patient_type_obs
                ON patient_type_obs.encounter_id = registration_encounter.encounter_id
                AND patient_type_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
                AND patient_type_obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('Drug refill', 'External consultation') AND voided = 0)
                AND patient_type_obs.voided = 0
              WHERE pp.voided = 0
            )
            GROUP BY person.person_id
          SQL
        end

        def individual_tpt_report(patient_id)
          result = process_current_tpt_course_date(patient_id)
          c_start_date = ActiveRecord::Base.connection.quote(result[:start_date])
          c_end_date = ActiveRecord::Base.connection.quote(client_tpt_end_date(patient_id, c_start_date))
          ActiveRecord::Base.connection.select_one <<-SQL
            SELECT
                CASE
                  WHEN tpt_transfer_in_obs.value_datetime IS NULL THEN DATE(MIN(o.start_date))
                  WHEN tpt_transfer_in_obs.value_datetime > MIN(o.start_date) THEN DATE(MIN(o.start_date))
                  ELSE DATE(tpt_transfer_in_obs.value_datetime)
                END AS tpt_initiation_date,
                COUNT(DISTINCT(DATE(o.start_date))) AS months_on_tpt,
                SUM(dor.quantity) + SUM(CASE WHEN tpt_transfer_in_obs.value_numeric IS NOT NULL THEN tpt_transfer_in_obs.value_numeric ELSE 0 END) AS total_pills_taken,
                SUM(DATEDIFF(o.auto_expire_date, o.start_date)) + SUM(CASE WHEN tpt_transfer_in_obs.value_datetime IS NOT NULL THEN DATEDIFF(tpt_transfer_in_obs.obs_datetime, tpt_transfer_in_obs.value_datetime) ElSE 0 END) AS total_days_on_medication,
                GROUP_CONCAT(DISTINCT o.concept_id SEPARATOR ',') AS drug_concepts,
                CASE
                  WHEN tpt_transfer_in_obs.value_numeric IS NOT NULL THEN 1
                  ELSE 0
                END AS transfer_in,
                MAX(o.start_date) AS last_dispensed_date
            FROM orders o
            INNER JOIN concept_name cn
              ON cn.concept_id = o.concept_id
              AND cn.name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')
            LEFT JOIN obs tpt_transfer_in_obs
              ON tpt_transfer_in_obs.person_id = o.patient_id
              AND tpt_transfer_in_obs.concept_id = #{ConceptName.find_by_name('TPT Drugs Received').concept_id}
              AND tpt_transfer_in_obs.voided = 0
              AND tpt_transfer_in_obs.value_drug IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')))
            INNER JOIN drug_order dor
              ON dor.order_id = o.order_id
              AND dor.quantity > 0
            WHERE DATE(o.start_date) BETWEEN DATE(#{c_start_date}) AND DATE(#{c_end_date})
            AND o.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
            AND o.voided = 0
            AND o.patient_id = #{patient_id}
            GROUP BY o.patient_id
          SQL
        end

        def process_current_tpt_course_date(patient_id)
          result = client_tpt_dates(patient_id)
          return { start_date: '1900-01-01', end_date: end_date } if result.blank?

          sorted_result = result.sort { |a, b| a['start_date'].to_date <=> b['start_date'].to_date }.reverse
          return_date = { start_date: sorted_result.last['start_date'], end_date: end_date }

          course_interruption = result.first['course'] == '3HP' ? 1 : 2
          # loop through the result array and find the first gap in the dates that equals the course interruption
          sorted_result.each_with_index do |row, index|
            next if index.zero?

            diff = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH,DATE('#{row['end_date']}'), DATE('#{sorted_result[index - 1]['start_date']}')) as months")['months']

            if diff.to_i >= course_interruption
              return_date = { start_date: sorted_result[index - 1]['start_date'], end_date: end_date }
              break
            end
          end
          return_date
        end

        def client_tpt_dates(patient_id)
          ActiveRecord::Base.connection.select_all <<~SQL
            (
              SELECT
                DATE(o.value_datetime) AS start_date,
                DATE(o.obs_datetime) AS end_date,
                CASE
                  WHEN count(distinct(o.value_drug)) > 1 THEN '3HP'
                  WHEN o.value_drug = #{isoniazid_rifapentine_drug.drug_id} THEN '3HP'
                  ELSE '6H'
                END AS course
              FROM obs o
              WHERE o.concept_id = #{ConceptName.find_by_name('TPT Drugs Received').concept_id}
              AND o.voided = 0
              AND o.value_drug IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')))
              AND o.person_id = #{patient_id}
              AND o.value_numeric IS NOT NULL
              AND DATE(o.obs_datetime) <= DATE(#{start_date})
              GROUP BY DATE(o.obs_datetime)
              ORDER BY DATE(o.obs_datetime) DESC
            )
            UNION
            (
              SELECT
                DATE(o.start_date) AS start_date,
                DATE(o.auto_expire_date) AS end_date,
                CASE
                  WHEN count(distinct(o.concept_id)) > 1 THEN '3HP'
                  WHEN o.concept_id = #{isoniazid_rifapentine_concept.concept_id} THEN '3HP'
                  ELSE '6H'
                END AS course
              FROM orders o
              INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1 /* HIV Program */
              INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
              WHERE o.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND o.voided = 0
              AND o.concept_id IN (#{ConceptName.where(name: ['Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine']).select(:concept_id).to_sql})
              AND o.patient_id = #{patient_id}
              AND o.auto_expire_date IS NOT NULL
              AND DATE(o.start_date) <= DATE(#{start_date})
              GROUP BY DATE(o.start_date)
              ORDER BY DATE(o.start_date) DESC
            )
          SQL
        end

        def client_tpt_end_date(patient_id, start_date)
          # Get patient tpt dispensations dates after the start date and before the end date
          result = ActiveRecord::Base.connection.select_all <<~SQL
            (
              SELECT
                DATE(o.value_datetime) AS start_date,
                DATE(MAX(o.obs_datetime)) AS end_date,
                CASE
                  WHEN count(distinct(o.value_drug)) > 1 THEN '3HP'
                  WHEN o.value_drug = #{isoniazid_rifapentine_drug.drug_id} THEN '3HP'
                  ELSE '6H'
                END AS course
              FROM obs o
              WHERE o.concept_id = #{ConceptName.find_by_name('TPT Drugs Received').concept_id}
              AND o.voided = 0
              AND o.value_drug IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name IN ('Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine')))
              AND o.person_id = #{patient_id}
              AND o.value_numeric IS NOT NULL
              AND DATE(o.obs_datetime) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
              GROUP BY DATE(o.obs_datetime)
              ORDER BY DATE(o.obs_datetime) DESC
            )
            UNION
            (
              SELECT
                DATE(o.start_date) AS start_date,
                DATE(MAX(o.auto_expire_date)) AS end_date,
                CASE
                  WHEN count(distinct(o.concept_id)) > 1 THEN '3HP'
                  WHEN o.concept_id = #{isoniazid_rifapentine_concept.concept_id} THEN '3HP'
                  ELSE '6H'
                END AS course
              FROM orders o
              INNER JOIN encounter e ON e.encounter_id = o.encounter_id AND e.voided = 0 AND e.program_id = 1 /* HIV Program */
              INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
              WHERE o.order_type_id IN (SELECT order_type_id FROM order_type WHERE name = 'Drug order')
              AND o.voided = 0
              AND o.concept_id IN (#{ConceptName.where(name: ['Rifapentine', 'Isoniazid', 'Isoniazid/Rifapentine']).select(:concept_id).to_sql})
              AND o.patient_id = #{patient_id}
              AND o.auto_expire_date IS NOT NULL
              AND DATE(o.start_date) BETWEEN DATE(#{start_date}) AND DATE(#{end_date})
              GROUP BY DATE(o.start_date)
              ORDER BY DATE(o.start_date) DESC
            )
          SQL

          return end_date if result.blank?

          sorted_result = result.sort { |a, b| a['start_date'].to_date <=> b['start_date'].to_date }
          return_date = sorted_result.last['end_date']
          course_interruption = result.first['course'] == '3HP' ? 1 : 2
          # use a for loop to check if there is a course interruption
          sorted_result.each_with_index do |row, i|
            next if i.zero?

            if row['course'] != sorted_result[i - 1]['course']
              return_date = sorted_result[i - 1]['end_date']
              break
            end
            diff = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH,DATE('#{sorted_result[i - 1]['end_date']}'),DATE('#{row['start_date']}')) as months")['months']
            if diff.to_i >= course_interruption
              return_date = sorted_result[i - 1]['end_date']
              break
            end
          end
          return_date
        end

        ##
        # Groups patients into their TPT categories (ie 6H and 3HP) based on their drugs
        #
        # Returns an object with a three_hp and six_h methods, each of which
        # is an array of patients for that category.
        def group_patients_by_tpt_course(patients)
          patients.each_with_object(OpenStruct.new(six_h: [], three_hp: [])) do |patient, categories|
            if patient_on_3hp?(patient)
              categories.three_hp << patient
            else
              categories.six_h << patient
            end
          end
        end

        def patient_history_on_completed_tpt(patient_id)
          @patient_history_on_completed_tpt ||= Observation.where(person_id: patient_id,
                                                                  concept_id: ConceptName.find_by_name('Previous TB treatment history').concept_id)
                                                           .where("value_text LIKE '%Completed%' AND obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY")&.first&.value_text
        end

        def patient_on_tb_treatment?(patient_id)
          Observation.where(person_id: patient_id, concept_id: ConceptName.find_by_name('TB status').concept_id,
                            value_coded: ConceptName.find_by_name('Confirmed TB on treatment').concept_id)
                     .where("obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY").exists?
        end

        def patient_on_3hp?(patient)
          drug_concepts = patient['drug_concepts'].split(',').collect(&:to_i)
          (drug_concepts & [rifapentine_concept.concept_id, isoniazid_rifapentine_concept&.concept_id]).any?
        end

        def rifapentine_concept
          @rifapentine_concept ||= ConceptName.find_by!(name: 'Rifapentine')
        end

        def isoniazid_rifapentine_concept
          @isoniazid_rifapentine_concept ||= ConceptName.find_by!(name: 'Isoniazid/Rifapentine')
        end

        def isoniazid_rifapentine_drug
          @isoniazid_rifapentine_drug ||= Drug.find_by!(concept_id: isoniazid_rifapentine_concept.concept_id)
        end
      end
    end
  end
end
