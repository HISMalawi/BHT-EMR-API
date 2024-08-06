# frozen_string_literal: true

module CxcaService
  module Reports
    module Moh
      # This class is responsible for generating the MOH CXCA report
      # rubocop:disable Metrics/ClassLength
      class ScreenedForCxca
        include ModelUtils
        attr_accessor :start_date, :end_date, :report

        SCREENING_METHOD = 'CxCa screening method'
        SCREENING_RESULT = 'Screening results'
        REFFERAL_REASONS = 'Referral reason'
        HIV_STATUS = 'HIV status'
        DOT_OPTION = 'Directly observed treatment option'
        SCREENING_ASSESMENT = 'Cervix screening assessment'
        TX_OPTION = 'Treatment'
        FAMILY_PLANNING = 'Family planning'
        OUTCOME = 'Outcome'
        CXCA_PROGRAM = 'CxCa Program'
        CXCA_TEST = 'CxCa test'
        REASON_FOR_VISIT = 'Reason for visit'
        POSITIVE_ON_ART = 'Positive on ART'
        HIV_TEST_DATE = 'HIV test date'
        CANCER_SUSPECT = 'Suspect Cancer'
        CANCER_SUSPECTED = 'Suspected Cancer'

        SCREENING_METHOD_MAP = {
          'VIA' => 'VIA'.to_sym,
          'Papanicolaou smear' => 'PAP Smear'.to_sym,
          'HPV DNA' => 'HPV DNA'.to_sym,
          'Speculum Exam' => 'Speculum Exam'.to_sym
        }.freeze

        AGE_GROUPS = ['<25 years', '25-29 years', '30-44 years', '45-49 years', '>49 years'].freeze

        SCREENING_RESULTS = {
          'HPV positive' => 'HPV+',
          'HPV negative' => 'HPV-',
          'VIA negative' => 'VIA-',
          'VIA positive' => 'VIA+',
          'PAP Smear normal' => 'PAP Smear normal',
          'PAP Smear abnormal' => 'PAP Smear abnormal',
          'No visible Lesion' => 'No visible Lesion',
          'Visible Lesion' => 'Visible Lesion',
          'Suspected Cancer' => 'Suspected Cancer'
        }.freeze

        HIV_STATUS_GROUP = {
          'Positive NOT on ART' => [],
          'Positive on ART' => [],
          'Negative' => [],
          'Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)' => []
        }.freeze

        REFERRAL_REASON_GROUP = {
          "Further Investigation and Management": [],
          "Large Lesion (Greater than 75 percent)": [],
          "Unable to treat client": [],
          "Suspect Cancer": [],
          "No treatment": [],
          "Other gynae": []
        }.freeze

        REASON_FOR_VISIT_GROUP = [
          'Initial Screening',
          'Postponed treatment',
          'One year subsequent check-up after treatment',
          'Subsequent screening',
          'Problem visit after treatment',
          'Referral'
        ].freeze

        SCREENING_METHOD_GROUP = SCREENING_METHOD_MAP.values.uniq.map(&:to_s).map(&:downcase).freeze

        SCREENING_RESULTS_GROUP = SCREENING_RESULTS.keys.uniq.map(&:downcase).freeze

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          init_report
          map_report
          report
        rescue StandardError => e
          Rails.logger.error "Error generating CXCA report: #{e.message}"
          e.backtrace.each { |line| Rails.logger.error line }
          raise e
        end

        private

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def map_report
          # rubocop:disable Metrics/BlockLength
          (query || []).each do |record|
            age_group = record['age_group']
            next unless AGE_GROUPS.include?(age_group)

            screening_method = SCREENING_METHOD_MAP[concept_id_to_name(record['screening_method'])]
            next unless screening_method.present?

            screening_result = concept_id_to_name(record['screening_result'])
            referral_reason = concept_id_to_name(record['referral_reason'])
            hiv_status = concept_id_to_name(record['hiv_status'])
            hiv_test_date = record['hiv_test_date']
            dot_option = concept_id_to_name(record['dot_option'])
            person_id = record['person_id']
            cancer_suspect = record['cancer_suspect']
            visit_reason = concept_id_to_name(record['visit_reason'])
            tx_option = concept_id_to_name(record['tx_option'])
            family_planning = concept_id_to_name(record['family_planning'])
            outcome = concept_id_to_name(record['outcome'])

            @report[:screened_disaggregated_by_age][age_group] << person_id if screening_method.present?
            handle_hiv_status(person_id, hiv_status, hiv_test_date, screening_method)
            handle_visit_reason(person_id, visit_reason, screening_method)
            handle_screening_method(screening_method, person_id)
            handle_screening_result(hiv_status, screening_result, person_id)
            @report[:suspects_disaggregated_by_age][age_group] << person_id if cancer_suspect.present?
            handle_dot_option(dot_option, person_id)
            handle_tx_option(tx_option, person_id)
            handle_referral_reason(referral_reason, person_id)
            handle_total_treated_by_age(tx_option, age_group, person_id)
            @report[:referral_feedback]['With referral feedback'] << person_id if outcome.present?
            handle_family_planning(family_planning, person_id)
          end
          # rubocop:enable Metrics/BlockLength
        end
        # rubocop:enable Metrics/AbcSize

        def init_report
          @report = {
            screened_disaggregated_by_age: {},
            screened_disaggregated_by_hiv_status: HIV_STATUS_GROUP,
            screened_disaggregated_by_reason_for_visit: {},
            screened_disaggregated_by_screening_method: {},
            screening_results_hiv_positive: initialize_screening_results_group,
            screening_results_hiv_negative: initialize_screening_results_group,
            suspects_disaggregated_by_age: {},
            total_treated: initialize_total_treated_group,
            total_treated_disaggregated_by_tx_option: initialize_total_treated_disaggregated_group,
            referral_reasons: REFERRAL_REASON_GROUP,
            total_treated_disaggregated_by_age: {},
            family_planning: { 'Yes' => [], 'No' => [], 'N/A' => [] },
            referral_feedback: { 'With referral feedback' => [] }
          }
          AGE_GROUPS.each do |key|
            @report[:suspects_disaggregated_by_age][key] ||= []
            @report[:screened_disaggregated_by_age][key] ||= []
            @report[:total_treated_disaggregated_by_age][key] ||= []
          end
        end
        # rubocop:enable Metrics/MethodLength

        def initialize_screening_results_group
          group = {}
          SCREENING_RESULTS.each_value do |result|
            group["Number of clients with #{result}"] = []
          end
          group
        end

        def initialize_total_treated_group
          {
            'Same day treatment' => [],
            'Postponed treatment' => [],
            'Referral' => [],
            'Postponed treatment perfomed' => []
          }
        end

        def initialize_total_treated_disaggregated_group
          {
            'Cryotherapy' => [],
            'Thermal Coagulation' => [],
            'LEEP' => [],
            'Other' => []
          }
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/PerceivedComplexity
        def handle_hiv_status(person_id, hiv_status, hiv_test_date, screening_method)
          return unless screening_method.present?

          indicator = @report[:screened_disaggregated_by_hiv_status]
          negative = ['Negative'].include?(hiv_status)
          test_date = hiv_test_date.present? if negative
          period = hiv_test_date&.to_date&.< end_date.to_date - 1.year if negative && test_date.present?
          unknown_cat = negative && test_date && period
          uncat = negative && hiv_test_date.blank?
          if hiv_status.blank? || ['Never Tested', 'Undisclosed'].include?(hiv_status) || unknown_cat || uncat
            sub_indicator = 'Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)'
            indicator[sub_indicator] ||= []
            indicator[sub_indicator] << person_id
          elsif ['Positive on ART', 'Positive NOT on ART', 'Negative'].include?(hiv_status)
            indicator[hiv_status] ||= []
            indicator[hiv_status] << person_id
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity

        def handle_visit_reason(person_id, visit_reason, screening_method)
          return unless visit_reason.present?
          return unless REASON_FOR_VISIT_GROUP.include?(visit_reason&.to_sym)

          @report[:screened_disaggregated_by_reason_for_visit][visit_reason] ||= []
          @report[:screened_disaggregated_by_reason_for_visit][visit_reason] << person_id if screening_method.present?
        end

        def handle_screening_method(screening_method, person_id)
          return if screening_method.blank?
          return unless SCREENING_METHOD_GROUP.include?(screening_method&.to_sym)

          @report[:screened_disaggregated_by_screening_method][screening_method] ||= []
          @report[:screened_disaggregated_by_screening_method][screening_method] << person_id
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/PerceivedComplexity
        def handle_screening_result(hiv_status, screening_result, person_id)
          return if screening_result.blank?

          key_sym = :screening_results_hiv_negative
          key_sym = :screening_results_hiv_positive if ['Positive on ART', 'Positive NOT on ART'].include?(hiv_status)
          if SCREENING_RESULTS_GROUP.include?(screening_result.downcase)
            @report[key_sym]["Number of clients with #{SCREENING_RESULTS[screening_result]}"] ||= []
            @report[key_sym]["Number of clients with #{SCREENING_RESULTS[screening_result]}"] << person_id
          elsif screening_result == 'Suspected cancer'
            @report[key_sym]['Number of clients with Suspected Cancer'] ||= []
            @report[key_sym]['Number of clients with Suspected Cancer'] << person_id
          else
            @report[key_sym]['Number of clients with Other gynae'] ||= []
            @report[key_sym]['Number of clients with Other gynae'] << person_id
          end
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity

        def handle_dot_option(dot_option, person_id)
          return if dot_option.blank?
          return if @report[:total_treated].keys.include?(dot_option&.to_sym)

          @report[:total_treated][dot_option] ||= []
          @report[:total_treated][dot_option] << person_id
        end

        def handle_tx_option(tx_option, person_id)
          return unless tx_option.present?

          if @report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
            @report[:total_treated_disaggregated_by_tx_option][tx_option] ||= []
            @report[:total_treated_disaggregated_by_tx_option][tx_option] << person_id
          else
            @report[:total_treated_disaggregated_by_tx_option]['Other'] ||= []
            @report[:total_treated_disaggregated_by_tx_option]['Other'] << person_id
          end
        end

        # rubocop:disable Metrics/AbcSize
        def handle_referral_reason(referral_reason, person_id)
          return unless referral_reason.present?

          if @report[:referral_reasons].keys.include?(referral_reason&.to_sym)
            @report[:referral_reasons][referral_reason.to_sym] << person_id
          elsif referral_reason == 'Suspect cancer'
            @report[:referral_reasons]['Suspect Cancer'.to_sym] << person_id
          else
            @report[:referral_reasons]['Other gynae'.to_sym] << person_id
          end
        end
        # rubocop:enable Metrics/AbcSize

        def handle_total_treated_by_age(tx_option, age_group, person_id)
          return if tx_option.blank?

          @report[:total_treated_disaggregated_by_age][age_group] ||= []
          @report[:total_treated_disaggregated_by_age][age_group] << person_id
        end

        def handle_family_planning(family_planning, person_id)
          return unless family_planning.present?

          if @report[:family_planning].keys.include?(family_planning)
            @report[:family_planning][family_planning] ||= []
            @report[:family_planning][family_planning] << person_id
          else
            @report[:family_planning]['N/A'] ||= []
            @report[:family_planning]['N/A'] << person_id
          end
        end

        # rubocop:disable Metrics/AbcSize
        def query
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              outcome.value_coded,
              family_planning.value_coded family_planning,
              tx_option.value_coded tx_option,
              screening_asesment.value_coded screening_asessment,
              cancer_suspect.patient_id cancer_suspect,
              reason_for_visit.value_coded visit_reason,
              screened_method.value_coded screening_method,
              screened_result.value_coded screening_result,
              referral_reason.value_coded referral_reason,
              COALESCE(client_on_art.client_on_art, hiv_status.value_coded, 9432) hiv_status, -- 9432 is the concept_id for Never Tested
              hiv_test_date.value_datetime hiv_test_date,
              dot_option.value_coded dot_option,
              p.person_id,
              cxca_moh_age_group(p.birthdate, DATE('#{@end_date}')) age_group
            FROM person p
            INNER JOIN encounter e ON e.patient_id = p.person_id
              AND e.program_id = #{program(CXCA_PROGRAM).id} AND e.encounter_datetime >= '#{@start_date}'
              AND e.encounter_datetime <= '#{@end_date}'
              AND e.encounter_type = #{encounter_type(CXCA_TEST).id}
              AND e.voided = 0
            LEFT JOIN (
              -- we need to check whether the client has received arv treatment on the facility before
              -- since the system does question the client when they are coming form ART
              SELECT o.patient_id, CASE WHEN count(*) > 0 THEN 10017 ELSE 0 END client_on_art
              FROM orders o
              INNER JOIN drug_order do ON do.order_id = o.order_id AND do.drug_inventory_id IN (SELECT drug_id FROM arv_drug) AND do.quantity > 0
              WHERE o.voided = 0 AND o.start_date <= '#{@end_date}'
              GROUP BY o.patient_id
            ) client_on_art ON client_on_art.patient_id = p.person_id AND client_on_art.client_on_art = 10017 -- 10017 is the concept_id for Positive on ART
            -- we need to get the HIV test date of the client
            LEFT JOIN (
              SELECT o.person_id, o.value_datetime
              FROM obs o
              INNER JOIN (
                SELECT person_id, MAX(obs_datetime) obs_datetime
                FROM obs
                WHERE concept_id = #{concept(HIV_TEST_DATE).concept_id}
                  AND voided = 0
                  AND obs_datetime <= '#{@end_date}'
                GROUP BY person_id
              ) latest_hiv_test_date ON latest_hiv_test_date.person_id = o.person_id AND latest_hiv_test_date.obs_datetime = o.obs_datetime
              WHERE o.concept_id = #{concept(HIV_TEST_DATE).concept_id} AND o.voided = 0
            ) hiv_test_date ON hiv_test_date.person_id = p.person_id
            LEFT JOIN obs screened_method ON screened_method.person_id = p.person_id
              AND screened_method.concept_id = #{concept(SCREENING_METHOD).concept_id}
              AND screened_method.voided = 0
              AND screened_method.obs_datetime >= '#{@start_date}'
              AND screened_method.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs screened_result ON screened_result.person_id = p.person_id
            	AND screened_result.concept_id = #{concept(SCREENING_RESULT).concept_id}
            	AND screened_result.voided = 0
              AND screened_result.obs_datetime >= '#{@start_date}'
              AND screened_result.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs referral_reason ON referral_reason.person_id = p.person_id
            	AND referral_reason.concept_id = #{concept(REFFERAL_REASONS).concept_id}
            	AND referral_reason.voided = 0
              AND referral_reason.obs_datetime >= '#{@start_date}'
              AND referral_reason.obs_datetime <= '#{@end_date}'
            -- we need to get the latest hiv status of the client
            LEFT JOIN (
              SELECT o.person_id, o.value_coded
              FROM obs o
              INNER JOIN (
                SELECT person_id, MAX(obs_datetime) obs_datetime
                FROM obs
                WHERE concept_id = #{concept(HIV_STATUS).concept_id}
                  AND voided = 0
                  AND obs_datetime <= '#{@end_date}'
                GROUP BY person_id
              ) latest_hiv_status ON latest_hiv_status.person_id = o.person_id AND latest_hiv_status.obs_datetime = o.obs_datetime
              WHERE o.concept_id = #{concept(HIV_STATUS).concept_id} AND o.voided = 0
            ) hiv_status ON hiv_status.person_id = p.person_id
            LEFT JOIN obs dot_option ON dot_option.person_id = p.person_id
            	AND dot_option.concept_id = #{concept(DOT_OPTION).concept_id}
            	AND dot_option.voided = 0
              AND dot_option.obs_datetime >= '#{@start_date}'
              AND dot_option.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs screening_asesment ON screening_asesment.person_id = p.person_id
            	AND screening_asesment.concept_id = #{concept(SCREENING_ASSESMENT).concept_id}
            	AND screening_asesment.voided = 0
              AND screening_asesment.obs_datetime >= '#{@start_date}'
              AND screening_asesment.obs_datetime <= '#{@end_date}'
            LEFT JOIN (
              SELECT e.patient_id
              FROM encounter e
              INNER JOIN obs o ON o.encounter_id = e.encounter_id
                AND o.value_coded IN (#{concept(CANCER_SUSPECT).concept_id}, #{concept(CANCER_SUSPECTED).concept_id})
                AND o.voided = 0
                AND o.obs_datetime >= '#{@start_date}'
                AND o.obs_datetime <= '#{@end_date}'
              WHERE e.program_id = #{program(CXCA_PROGRAM).id}
                AND e.encounter_datetime >= '#{@start_date}'
                AND e.encounter_datetime <= '#{@end_date}'
                AND e.voided = 0
              GROUP BY e.patient_id
            ) cancer_suspect ON cancer_suspect.patient_id = p.person_id
            LEFT JOIN obs tx_option ON tx_option.person_id = p.person_id
            	AND tx_option.concept_id = #{concept(TX_OPTION).concept_id}
            	AND tx_option.voided = 0
              AND tx_option.obs_datetime >= '#{@start_date}'
              AND tx_option.obs_datetime <= '#{@end_date}'
            LEFT JOIN (
              SELECT e.patient_id, family_planning.value_coded
              FROM encounter e
              INNER JOIN obs family_planning ON family_planning.encounter_id = e.encounter_id
                AND family_planning.concept_id = #{concept(FAMILY_PLANNING).concept_id}
                AND family_planning.voided = 0
                AND family_planning.obs_datetime >= '#{@start_date}'
                AND family_planning.obs_datetime <= '#{@end_date}'
              WHERE e.program_id = #{program(CXCA_PROGRAM).id}
                AND e.encounter_datetime >= '#{@start_date}'
                AND e.encounter_datetime <= '#{@end_date}'
                AND e.voided = 0
              GROUP BY e.patient_id
            ) family_planning ON family_planning.patient_id = p.person_id
            LEFT JOIN obs outcome ON outcome.person_id = p.person_id
            	AND outcome.concept_id = #{concept(OUTCOME).concept_id}
            	AND outcome.voided = 0
              AND outcome.obs_datetime >= '#{@start_date}'
              AND outcome.obs_datetime <= '#{@end_date}'
            INNER JOIN obs reason_for_visit ON reason_for_visit.person_id = p.person_id
              AND reason_for_visit.encounter_id = e.encounter_id
            	AND reason_for_visit.voided = 0
            	AND reason_for_visit.concept_id = #{concept(REASON_FOR_VISIT).concept_id}
              AND reason_for_visit.obs_datetime >= '#{@start_date}'
              AND reason_for_visit.obs_datetime <= '#{@end_date}'
            WHERE p.voided = 0 AND LEFT(p.gender, 1) = 'F'
            GROUP BY p.person_id
          SQL
        end
        # rubocop:enable Metrics/AbcSize
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
