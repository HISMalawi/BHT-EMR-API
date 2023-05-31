# frozen_string_literal: true

module ARTService
  module Reports
    ##
    # Family planning, action to take
    # It should pull data for 6 month back e.g when the report is generated for the month of June,
    # the report must pick clients who started TPT in the month of December
    # it must be drillable
    class TptOutcome
      include ModelUtils
      include ARTService::Reports::Pepfar::Utils

      def initialize(start_date:, end_date:, **_kwarg)
        @start_date = start_date.to_date
        @end_date = end_date.to_date
        @tb_prev = ARTService::Reports::Pepfar::TbPrev3.new(start_date: @start_date, end_date: @end_date)
      end

      def find_report
        report = init_report
        load_patients_into_report report, process_tpt_clients
        response = []
        report.each do |key, value|
          response << { age_group: key, tpt_type: '3HP', **value['3HP'] }
          response << { age_group: key, tpt_type: '6H', **value['6H'] }
        end
        response
      end

      def moh_report(report, clients, start_date, end_date)
        @first_day_of_month = start_date.to_date
        @last_day_of_month = end_date.to_date
        tpt_clients = process_tpt_clients(clients)
        load_patients_into_report report, tpt_clients, 'gender'
      end

      private

      TPT_TYPES = %w[3HP 6H].freeze

      def init_report
        pepfar_age_groups.each_with_object({}) do |age_group, report|
          next if age_group == 'Unknown'

          report[age_group] = TPT_TYPES.each_with_object({}) do |tpt_type, tpt_report|
            tpt_report[tpt_type] = {
              started_tpt: [],
              completed_tpt: [],
              not_completed_tpt: [],
              died: [],
              stopped: [],
              defaulted: [],
              transfer_out: [],
              confirmed_tb: [],
              pregnant: [],
              breast_feeding: [],
              skin_rash: [],
              peripheral_neuropathy: [],
              yellow_eyes: [],
              nausea: [],
              dizziness: []
            }
          end
        end
      end

      def patient_breast_feeding?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: breast_feeding_concept_id,
                          value_coded: yes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .exists?
      end

      def patient_skin_rash?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: drug_induced_concept_id,
                          value_coded: skin_rash_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .where("value_drug IN (#{tpt_actual_drugs})")
                   .exists?
      end

      def patient_peripheral_neuropathy?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: drug_induced_concept_id,
                          value_coded: peripheral_neuropathy_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .where("value_drug IN (#{tpt_actual_drugs})")
                   .exists?
      end

      def patient_pregnant?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: pregnant_concept_id,
                          value_coded: yes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .exists?
      end

      def patient_on_tb_treatment?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: tb_treatment_concept_id,
                          value_coded: yes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .exists?
      end

      def patient_yellow_eyes?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: drug_induced_concept_id,
                          value_coded: yellow_eyes_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .where("value_drug IN (#{tpt_actual_drugs})")
                   .exists?
      end

      def patient_nausea?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: drug_induced_concept_id,
                          value_coded: nausea_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .where("value_drug IN (#{tpt_actual_drugs})")
                   .exists?
      end

      def patient_dizziness?(patient_id, last_tpt)
        Observation.where(person_id: patient_id, concept_id: drug_induced_concept_id,
                          value_coded: dizziness_concept_id)
                   .where('DATE(obs_datetime) > DATE(?) AND DATE(obs_datetime) < DATE(?) + INTERVAL 1 DAY', last_tpt.to_date, @end_date.to_date)
                   .where("value_drug IN (#{tpt_actual_drugs})")
                   .exists?
      end

      def pregnant_concept_id
        @pregnant_concept_id ||= concept_name_to_id('Is patient pregnant?')
      end

      def tb_treatment_concept_id
        @tb_treatment_concept_id ||= concept_name_to_id('TB treatment')
      end

      def yes_concept_id
        @yes_concept_id ||= concept_name_to_id('Yes')
      end

      def breast_feeding_concept_id
        @breast_feeding_concept_id ||= concept_name_to_id('Breast feeding?')
      end

      def skin_rash_concept_id
        @skin_rash_concept_id ||= concept_name_to_id('Skin rash')
      end

      def peripheral_neuropathy_concept_id
        @peripheral_neuropathy_concept_id ||= concept_name_to_id('Peripheral neuropathy')
      end

      def yellow_eyes_concept_id
        @yellow_eyes_concept_id ||= concept_name_to_id('Yellow eyes')
      end

      def nausea_concept_id
        @nausea_concept_id ||= concept_name_to_id('Nausea')
      end

      def dizziness_concept_id
        @dizziness_concept_id ||= concept_name_to_id('Dizziness')
      end

      def drug_induced_concept_id
        @drug_induced_concept_id ||= concept_name_to_id('Drug Induced')
      end

      def tpt_clients
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            pp.patient_id,
            patient_outcome(p.person_id, DATE('#{@end_date}')) AS outcome,
            p.gender,
            p.birthdate,
            disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) AS age_group,
            GROUP_CONCAT(DISTINCT o.concept_id SEPARATOR ',') AS drug_concepts,
            CASE
              WHEN count(DISTINCT o.concept_id) >  1 THEN '3HP'
              WHEN o.concept_id = 10565 THEN '3HP'
              ELSE '6H'
            END AS tpt_type
          FROM patient_program pp
          INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7
          INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
          INNER JOIN encounter e ON e.patient_id = pp.patient_id
            AND e.encounter_type = 25 /* Treatment */
            AND e.voided = 0
            AND e.program_id = 1 /* HIV Program */
          INNER JOIN orders o ON o.encounter_id = e.encounter_id
            AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
            AND o.voided = 0
            AND o.concept_id IN (#{tpt_drugs.to_sql})
          INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
          INNER JOIN (
            SELECT e.patient_id
            FROM encounter e
            INNER JOIN orders o ON o.encounter_id = e.encounter_id
              AND o.voided = 0
              AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
              AND o.concept_id IN (#{tpt_drugs.to_sql})
              AND DATE(o.start_date) BETWEEN #{first_day_of_month} AND DATE(#{last_day_of_month})
            INNER JOIN drug_order dor ON dor.order_id = o.order_id AND dor.quantity > 0
            WHERE e.encounter_type = 25 /* Treatment */
              AND e.voided = 0
              AND e.program_id = 1 /* HIV Program */
              AND DATE(e.encounter_datetime) BETWEEN #{first_day_of_month} AND DATE(#{last_day_of_month})
            GROUP BY e.patient_id
          ) clients_on_tpt ON clients_on_tpt.patient_id = e.patient_id
          WHERE pp.program_id = 1 /* HIV Program */
            AND pp.patient_id  NOT IN (
              /* External consultations */
              SELECT DISTINCT registration_encounter.patient_id
              FROM patient_program
              INNER JOIN program ON program.name = 'HIV Program'
              INNER JOIN encounter AS registration_encounter
                ON registration_encounter.patient_id = patient_program.patient_id
                AND registration_encounter.program_id = patient_program.program_id
                AND registration_encounter.encounter_datetime < DATE(#{@end_date}) + INTERVAL 1 DAY
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
                WHERE encounter.encounter_datetime < DATE(#{@end_date}) AND encounter.voided = 0
                GROUP BY encounter.patient_id
              ) AS max_registration_encounter
                ON max_registration_encounter.patient_id = registration_encounter.patient_id
                AND max_registration_encounter.encounter_datetime = registration_encounter.encounter_datetime
              INNER JOIN obs AS patient_type_obs
                ON patient_type_obs.encounter_id = registration_encounter.encounter_id
                AND patient_type_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
                AND patient_type_obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('Drug refill', 'External consultation') AND voided = 0)
                AND patient_type_obs.voided = 0
              WHERE patient_program.voided = 0
            )
            AND pp.voided = 0
            AND DATE(o.start_date)<= DATE('#{@end_date}')
            GROUP BY pp.patient_id
        SQL
      end

      def process_tpt_clients(patients = nil)
        clients = []
        (patients || tpt_clients).each do |client|
          result = @tb_prev.fetch_individual_report(client['patient_id'])
          next if result.blank?
          next if result['tpt_initiation_date'].to_date < first_day_of_month.to_date

          client['start_date'] = result['tpt_initiation_date']
          client['last_dispense_date'] = result['last_dispensed_date']
          client['total_pills_taken'] = result['total_pills_taken']
          client['total_days_on_medication'] = result['total_days_on_medication']

          clients << client
        end
        clients
      end

      # def tpt_clients
      #   ActiveRecord::Base.connection.select_all <<~SQL
      #     SELECT
      #       p.person_id AS patient_id,
      #       DATE(min(o.start_date)) AS start_date,
      #       DATE(max(o.start_date)) AS last_dispense_date,
      #       patient_outcome(p.person_id, DATE('#{@end_date}')) AS outcome,
      #       SUM(d.quantity) AS total_pills_taken,
      #       SUM(DATEDIFF(o.auto_expire_date, o.start_date)) AS total_days_on_medication,
      #       p.gender,
      #       p.birthdate,
      #       disaggregated_age_group(p.birthdate, DATE('#{@end_date}')) AS age_group,
      #       GROUP_CONCAT(DISTINCT o.concept_id SEPARATOR ',') AS drug_concepts,
      #       CASE
      #         WHEN count(DISTINCT o.concept_id) >  1 THEN '3HP'
      #         WHEN o.concept_id = 10565 THEN '3HP'
      #         ELSE '6H'
      #       END AS tpt_type
      #     FROM person p
      #     INNER JOIN encounter e
      #       ON e.patient_id = p.person_id
      #       AND e.encounter_type = #{EncounterType.find_by_name('Treatment').id}
      #       AND e.voided = 0
      #       AND e.program_id = #{Program.find_by_name('HIV PROGRAM').id}
      #       AND e.encounter_datetime >= DATE('#{@start_date}') - INTERVAL 6 MONTH
      #       AND e.encounter_datetime <= DATE('#{@start_date}')
      #     INNER JOIN orders o
      #       ON o.encounter_id = e.encounter_id
      #       AND o.concept_id IN (#{tpt_drugs.to_sql})
      #       AND o.start_date >= DATE('#{@start_date}') - INTERVAL 6 MONTH
      #       AND o.start_date <= DATE('#{@end_date}')
      #       AND o.voided = 0
      #       AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
      #     INNER JOIN drug_order d ON d.order_id = o.order_id AND d.quantity > 0
      #     WHERE p.voided = 0
      #     AND p.person_id NOT IN (
      #       SELECT p.person_id
      #       FROM person p
      #       INNER JOIN encounter e
      #         ON e.patient_id = p.person_id
      #         AND e.encounter_type = #{EncounterType.find_by_name('Treatment').id}
      #         AND e.voided = 0
      #         AND e.program_id = #{Program.find_by_name('HIV PROGRAM').id}
      #       INNER JOIN orders o
      #         ON o.patient_id = e.patient_id
      #         AND o.concept_id IN (#{tpt_drugs.to_sql})
      #         AND o.voided = 0
      #         AND o.order_type_id = #{OrderType.find_by_name('Drug order').id}
      #       INNER JOIN drug_order d ON d.order_id = o.order_id AND d.quantity > 0
      #       WHERE p.voided = 0
      #         AND e.encounter_datetime < '#{@start_date - 6.months}'
      #         AND e.encounter_datetime >= '#{@start_date - 15.months}'
      #     )
      #     AND p.person_id NOT IN (
      #       /* External consultations */
      #       SELECT DISTINCT registration_encounter.patient_id
      #       FROM patient_program
      #       INNER JOIN program ON program.name = 'HIV Program'
      #       INNER JOIN encounter AS registration_encounter
      #         ON registration_encounter.patient_id = patient_program.patient_id
      #         AND registration_encounter.program_id = patient_program.program_id
      #         AND registration_encounter.encounter_datetime < DATE(#{@end_date}) + INTERVAL 1 DAY
      #         AND registration_encounter.voided = 0
      #       INNER JOIN (
      #         SELECT MAX(encounter.encounter_datetime) AS encounter_datetime, encounter.patient_id
      #         FROM encounter
      #         INNER JOIN encounter_type
      #           ON encounter_type.encounter_type_id = encounter.encounter_type
      #           AND encounter_type.name = 'Registration'
      #         INNER JOIN program
      #           ON program.program_id = encounter.program_id
      #           AND program.name = 'HIV Program'
      #         WHERE encounter.encounter_datetime < DATE(#{@end_date}) AND encounter.voided = 0
      #         GROUP BY encounter.patient_id
      #       ) AS max_registration_encounter
      #         ON max_registration_encounter.patient_id = registration_encounter.patient_id
      #         AND max_registration_encounter.encounter_datetime = registration_encounter.encounter_datetime
      #       INNER JOIN obs AS patient_type_obs
      #         ON patient_type_obs.encounter_id = registration_encounter.encounter_id
      #         AND patient_type_obs.concept_id IN (SELECT concept_id FROM concept_name WHERE name = 'Type of patient' AND voided = 0)
      #         AND patient_type_obs.value_coded IN (SELECT concept_id FROM concept_name WHERE name IN ('Drug refill', 'External consultation') AND voided = 0)
      #         AND patient_type_obs.voided = 0
      #       WHERE patient_program.voided = 0
      #     )
      #     GROUP BY p.person_id
      #   SQL
      # end

      def load_patients_into_report(report, patients, param = 'tpt_type')
        patients.each do |patient|
          report[patient['age_group']][patient[param]][:started_tpt] << patient['patient_id']
          if patient_completed_tpt?(patient, patient['tpt_type'])
            report[patient['age_group']][patient[param]][:completed_tpt] << patient['patient_id']
          else
            report[patient['age_group']][patient[param]][:not_completed_tpt] << patient['patient_id']
            process_outcomes report, patient, param
          end
        end
      end

      def process_outcomes(report, patient, param = 'tpt_type')
        process_patient_conditions report, patient
        return if @condition

        case patient['outcome']
        when 'Patient died'
          report[patient['age_group']][patient[param]][:died] << patient['patient_id']
        when 'Patient transferred out'
          report[patient['age_group']][patient[param]][:transfer_out] << patient['patient_id']
        when 'Treatment stopped'
          report[patient['age_group']][patient[param]][:stopped] << patient['patient_id']
        when 'Defaulted'
          report[patient['age_group']][patient[param]][:defaulted] << patient['patient_id']
        else
          process_patient_conditions report, patient, param
        end
      end

      def process_patient_conditions(report, patient, param = 'tpt_type')
        if patient_on_tb_treatment?(patient['patient_id'], patient['last_dispense_date'])
          report[patient['age_group']][patient[param]][:confirmed_tb] << patient['patient_id']
        elsif patient['gender'] == 'F' && patient_pregnant?(patient['patient_id'], patient['last_dispense_date'])
          report[patient['age_group']][patient[param]][:pregnant] << patient['patient_id']
          @condition = true
          return
        elsif patient['gender'] == 'F' && patient_breast_feeding?(patient['patient_id'], patient['last_dispense_date'])
          report[patient['age_group']][patient['tpt_type']][:breast_feeding] << patient['patient_id']
          @condition = true
          return
        end

        process_malawi_art_conditions report, patient
      end

      def process_malawi_art_conditions(report, patient)
        %i[skin_rash nausea peripheral_neuropathy dizziness yellow_eyes].each do |condition|
          method_name = "patient_#{condition}?".to_sym
          next unless send(method_name, patient['patient_id'], patient['last_dispense_date'])

          report[patient['age_group']][patient['tpt_type']][condition] << patient['patient_id']
          @condition = true
        end
      end

      def tpt_drugs
        ConceptName.where(name: ['INH', 'Isoniazid/Rifapentine', 'Rifapentine']).select(:concept_id)
      end

      def tpt_actual_drugs
        @tpt_actual_drugs ||= Drug.where(concept_id: tpt_drugs.map(&:concept_id)).select(:drug_id).to_sql
      end

      def first_day_of_month
        @first_day_of_month ||= ActiveRecord::Base.connection.quote((@start_date - 6.month).beginning_of_month)
      end

      def last_day_of_month
        @last_day_of_month ||= ActiveRecord::Base.connection.quote((@start_date - 6.month).end_of_month)
      end
    end
  end
end
