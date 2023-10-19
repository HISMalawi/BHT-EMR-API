# rubocop:disable Metrics/AbcSize
# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Style/Documentation
module CXCAService
  module Reports
    module Moh
      class ScreenedForCxca
        include ModelUtils
        attr_accessor :start_date, :end_date, :report

        def initialize(start_date:, end_date:)
          @start_date = start_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.strftime('%Y-%m-%d 23:59:59')
        end

        SCREENING_METHOD = 'CxCa screening method'
        SCREENING_RESULTS = 'Screening results'
        REFFERAL_REASONS = 'Referral reason'
        SCREENING_METHOD = 'CxCa screening method'
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
        AGE_GROUPS = ['<25 years', '25-29 years', '30-44 years', '45-49 years', '>49 years'].freeze

        SCREENING_METHOD_MAP = {
          'VIA': 'VIA'.to_sym,
          'Papanicolaou smear': 'PAP Smear'.to_sym,
          'HPV DNA': 'HPV DNA'.to_sym,
          'Speculum Exam': 'Speculum Exam'.to_sym
        }.freeze

        def data
          init_report
          map_report
          report
        end

        private

        def map_report
          (query || []).each do |record|
            age_group = record['age_group']
            next unless AGE_GROUPS.include?(age_group)

            screening_method = record['screening_method'] ? SCREENING_METHOD_MAP[concept_id_to_name(record['screening_method']).to_sym] : nil
            screening_result = concept_id_to_name(record['screening_result'])
            referral_reason = concept_id_to_name(record['referral_reason'])
            hiv_status = concept_id_to_name(record['hiv_status'])
            hiv_test_date = record['hiv_test_date']
            dot_option = concept_id_to_name(record['dot_option'])
            person_id = record['person_id']
            # screening_asesment = concept_id_to_name(record['screening_asesment'])
            cancer_suspect = record['cancer_suspect']
            visit_reason = concept_id_to_name(record['visit_reason'])
            tx_option = concept_id_to_name(record['tx_option'])
            family_planning = concept_id_to_name(record['family_planning'])
            outcome = concept_id_to_name(record['outcome'])

            @report[:screened_disaggregated_by_age][age_group] << person_id if screening_method.present?

            if hiv_status.blank? || ['Never Tested', 'Undisclosed'].include?(hiv_status) || (['Negative'].include?(hiv_status) && hiv_test_date.present? && hiv_test_date.to_date < end_date.to_date - 1.year)
              @report[:screened_disaggregated_by_hiv_status]['Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)'] << person_id if screening_method.present?
            end

            if ['Positive on ART', 'Positive NOT on ART'].include?(hiv_status) || ((['Negative'].include?(hiv_status) && hiv_test_date.present? && hiv_test_date.to_date > end_date.to_date - 1.year))
              @report[:screened_disaggregated_by_hiv_status][hiv_status] ||= []
              @report[:screened_disaggregated_by_hiv_status][hiv_status] << person_id if screening_method.present?
            end

            if visit_reason.present? && @report[:screened_disaggregated_by_reason_for_visit].keys.include?(visit_reason&.to_sym)
              @report[:screened_disaggregated_by_reason_for_visit][visit_reason] ||= []
              @report[:screened_disaggregated_by_reason_for_visit][visit_reason] << person_id if screening_method.present?
            end

            if screening_method.present? && @report[:screened_disaggregated_by_screening_method].keys.include?(screening_method&.to_sym)
              @report[:screened_disaggregated_by_screening_method][screening_method] ||= []
              @report[:screened_disaggregated_by_screening_method][screening_method] << person_id
            end

            if screening_result.present?
              key_sym = ['Positive Not on ART', 'Positive on ART'].include?(hiv_status) ? :screening_results_hiv_positive : :screening_results_hiv_negative
              if screening_result.downcase == 'HPV positive'.downcase
                @report[key_sym]['Number of clients with HPV+'.to_sym] << person_id
              elsif screening_result.downcase == 'HPV negative'.downcase
                @report[key_sym]['Number of clients with HPV-'.to_sym] << person_id
              elsif screening_result.downcase == 'VIA negative'.downcase
                @report[key_sym]['Number of clients with VIA-'.to_sym] << person_id
              elsif screening_result.downcase == 'VIA positive'.downcase
                @report[key_sym]['Number of clients with VIA+'.to_sym] << person_id
              elsif screening_result.downcase == 'PAP Smear normal'.downcase
                @report[key_sym]['Number of clients with PAP Smear normal'.to_sym] << person_id
              elsif screening_result.downcase == 'PAP Smear abnormal'.downcase
                @report[key_sym]['Number of clients with PAP Smear abnormal'.to_sym] << person_id
              elsif screening_result.downcase == 'No visible Lesion'.downcase
                @report[key_sym]['Number of clients with No visible Lesion'.to_sym] << person_id
              elsif screening_result.downcase == 'Visible Lesion'.downcase
                @report[key_sym]['Number of clients with Visible Lesion'.to_sym] << person_id
              elsif screening_result.downcase == 'Suspected Cancer'.downcase
                @report[key_sym]['Number of clients with Suspected Cancer'.to_sym] << person_id
              else
                @report[key_sym]['Number of clients with Other gynae'&.to_sym] << person_id
              end
              @report[key_sym][screening_result] << person_id if @report[key_sym].keys.include?(screening_result&.to_sym)
            end
            @report[:suspects_disaggregated_by_age][age_group] << person_id if cancer_suspect.present?

            if dot_option.present? && report[:total_treated].keys.include?(dot_option&.to_sym)
              @report[:total_treated][dot_option] ||= []
              @report[:total_treated][dot_option] << person_id
            end

            if tx_option.present? && @report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option][tx_option] ||= [] if tx_option.present?
              @report[:total_treated_disaggregated_by_tx_option][tx_option] << person_id
            end

            if tx_option.present? && !@report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option]['Other'&.to_sym] << person_id
            end

            referral_reason = referral_reason == 'Suspect cancer' ? 'Suspect Cancer' : referral_reason
            if referral_reason.present? && @report[:referral_reasons].keys.include?(referral_reason&.to_sym)
              @report[:referral_reasons][referral_reason.to_sym] ||= []
              @report[:referral_reasons][referral_reason.to_sym] << person_id
            end

            if referral_reason.present? && !@report[:referral_reasons].keys.include?(referral_reason&.to_sym)
              @report[:referral_reasons]['Other gynae'&.to_sym] << person_id
            end

            if tx_option.present?
              @report[:total_treated_disaggregated_by_age][age_group] ||= []
              @report[:total_treated_disaggregated_by_age][age_group] << person_id
            end
            @report[:referral_feedback]['With referral feedback'] << person_id if outcome.present?

            if family_planning.present? && @report[:family_planning].keys.include?(family_planning&.to_sym)
              @report[:family_planning][family_planning] ||= [] if family_planning.present?
              @report[:family_planning][family_planning] << person_id
            end

            unless @report[:family_planning].keys.include?(family_planning&.to_sym)
              @report[:family_planning]['N/A'&.to_sym] << person_id
            end
          end
        end

        # rubocop:disable Metrics/MethodLength
        def init_report
          @report = {
            screened_disaggregated_by_age: {},
            screened_disaggregated_by_hiv_status: {
              "Positive NOT on ART": [],
              "Positive on ART": [],
              "Negative": [],
              "Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)": []
            },
            screened_disaggregated_by_reason_for_visit: {
              "Initial Screening": [],
              "Postponed treatment": [],
              "One year subsequent check-up after treatment": [],
              "Subsequent screening": [],
              "Problem visit after treatment": [],
              "Referral": []
            },
            screened_disaggregated_by_screening_method: {
              "VIA": [],
              "PAP Smear": [],
              "HPV DNA": [],
              "Speculum Exam": []
            },
            screening_results_hiv_positive: {
              "Number of clients with HPV+": [],
              "Number of clients with HPV-": [],
              "Number of clients with VIA-": [],
              "Number of clients with VIA+": [],
              "Number of clients with PAP Smear normal": [],
              "Number of clients with PAP Smear Abnormal": [],
              "Number of clients with No visible Lesion": [],
              "Number of clients with Visible Lesion": [],
              "Number of clients with Suspected Cancer": [],
              "Number of clients with Other gynae": []
            },
            screening_results_hiv_negative: {
              "Number of clients with HPV+": [],
              "Number of clients with HPV-": [],
              "Number of clients with VIA-": [],
              "Number of clients with VIA+": [],
              "Number of clients with PAP Smear normal": [],
              "Number of clients with PAP Smear Abnormal": [],
              "Number of clients with No visible Lesion": [],
              "Number of clients with Visible Lesion": [],
              "Number of clients with Suspected Cancer": [],
              "Number of clients with Other gynae": []
            },
            suspects_disaggregated_by_age: {},
            total_treated: {
              "Same day treatment": [],
              "Postponed treatment": [],
              "Referral": [],
              "Postponed treatment perfomed": []
            },
            total_treated_disaggregated_by_tx_option: {
              'Cryotherapy': [],
              'Thermal Coagulation': [],
              'LEEP': [],
              'Other': []
            },
            referral_reasons: {
              "Further Investigation and Management": [],
              "Large Lesion (Greater than 75 percent)": [],
              "Unable to treat client": [],
              "Suspect Cancer": [],
              "No treatment": [],
              "Other gynae": []
            },
            total_treated_disaggregated_by_age: {},
            family_planning: {
              'Yes': [],
              'No': [],
              'N/A': []
            },
            referral_feedback: {
              "With referral feedback": []
            }
          }
          AGE_GROUPS.each do |key|
            @report[:suspects_disaggregated_by_age][key] ||= []
            @report[:screened_disaggregated_by_age][key] ||= []
            @report[:total_treated_disaggregated_by_age][key] ||= []
          end
          @report[:screened_disaggregated_by_hiv_status]['Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)'] ||= []
        end
        # rubocop:enable Metrics/MethodLength

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
              cxca_moh_age_group(p.birthdate, DATE(e.encounter_datetime)) age_group
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
            	AND screened_result.concept_id = #{concept(SCREENING_RESULTS).concept_id}
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
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength, Style/Documentation, Metrics/AbcSize
