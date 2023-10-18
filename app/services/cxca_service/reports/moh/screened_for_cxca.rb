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

        AGE_GROUPS = ['<25 years', '25-29 years', '30-44 years', '45-49 years', '>49 years'].freeze

        def data
          init_report
          map_report
          report
        end

        private

        def get_concept_name(concept_id)
          concept = ConceptName.find_by_concept_id(concept_id).name if concept_id.present?
          return concept unless concept.blank?

          nil
        end

        def map_report
          (query || []).each do |record|
            age_group = record['age_group']

            screening_method = get_concept_name(record['screening_method'])
            screening_result = get_concept_name(record['screening_result'])
            referral_reason = get_concept_name(record['referral_reason'])
            hiv_status = get_concept_name(record['hiv_status'])
            dot_option = get_concept_name(record['dot_option'])
            person_id = record['person_id']
            screening_asesment = get_concept_name(record['screening_asesment'])
            visit_reason = get_concept_name(record['visit_reason'])
            tx_option = get_concept_name(record['tx_option'])
            family_planning = get_concept_name(record['family_planning'])
            outcome = get_concept_name(record['outcome'])

            @age_groups.each do |key, value|
              @report[:screened_disaggregated_by_age][key] << person_id if value.include?(age_group)
            end

            if hiv_status.present? && hiv_status == 'Never Tested'
              @report[:screened_disaggregated_by_hiv_status]['Unknown (HIV- > 1 year ago, Inconclusive, Prefers not to Disclose, or Never Tested)'] << person_id
            end

            if hiv_status.present? && report[:screened_disaggregated_by_hiv_status].keys.include?(hiv_status&.to_sym)
              @report[:screened_disaggregated_by_hiv_status][hiv_status] ||= []
              @report[:screened_disaggregated_by_hiv_status][hiv_status] << person_id
            end

            if visit_reason.present? && report[:screened_disaggregated_by_reason_for_visit].keys.include?(visit_reason&.to_sym)
              @report[:screened_disaggregated_by_reason_for_visit][visit_reason] ||= []
              @report[:screened_disaggregated_by_reason_for_visit][visit_reason] << person_id
            end

            if screening_method.present? && report[:screened_disaggregated_by_screening_method].keys.include?(screening_method&.to_sym)
              @report[:screened_disaggregated_by_screening_method][screening_method] ||= []
              @report[:screened_disaggregated_by_screening_method][screening_method] << person_id
            end
            if screening_result.present? && ['Positive Not on ART', 'Positive on ART'].include?(hiv_status&.to_sym) && report[:screening_results_hiv_positive].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_positive][screening_result] ||= []
              if screening_result == 'HPV positive'
                @report[:screening_results_hiv_positive]['Number of clients with HPV+'] << person_id
              end
              if screening_result == 'HPV negative'
                @report[:screening_results_hiv_positive]['Number of clients with HPV-'] << person_id
              end
              if screening_result == 'VIA negative'
                @report[:screening_results_hiv_positive]['Number of clients with VIA-'] << person_id
              end
              if screening_result == 'VIA positive'
                @report[:screening_results_hiv_positive]['Number of clients with VIA+'] << person_id
              end
              if screening_result == 'PAP Smear normal'
                @report[:screening_results_hiv_positive]['Number of clients with PAP Smear normal'] << person_id
              end
              if screening_result == 'PAP Smear abnormal'
                @report[:screening_results_hiv_positive]['Number of clients with PAP Smear abnormal'] << person_id
              end
              if screening_result == 'No visible Lesion'
                @report[:screening_results_hiv_positive]['Number of clients with No visible Lesion'] << person_id
              end
              if screening_result == 'Visible Lesion'
                @report[:screening_results_hiv_positive]['Number of clients with Visible Lesion'] << person_id
              end
              if screening_result == 'Suspected Cancer'
                @report[:screening_results_hiv_positive]['Number of clients with Suspected Cancer'] << person_id
              end
              @report[:screening_results_hiv_positive][screening_result] << person_id
            end
            if screening_result.present? && !report[:screening_results_hiv_positive].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_positive]['Number of clients with Other gynae'&.to_sym] << person_id
            end

            # assiging accurate template values to screening_result
            screening_result = screening_result == 'PAP Smear normal' ? 'Number of clients with PAP Smear normal' : screening_result
            screening_result = screening_result == 'HPV positive' ? 'Number of clients with HPV+' : screening_result
            screening_result = screening_result == 'HPV negative' ? 'Number of clients with HPV-' : screening_result
            screening_result = screening_result == 'VIA negative' ? 'Number of clients with VIA-' : screening_result
            screening_result = screening_result == 'VIA positive' ? 'Number of clients with VIA+' : screening_result
            screening_result = screening_result == 'PAP Smear Abnormal' ? 'Number of clients with PAP Smear Abnormal' : screening_result
            screening_result = screening_result == 'No visible Lesion' ? 'Number of clients with No visible Lesion' : screening_result
            screening_result = screening_result == 'Visible Lesion' ? 'Number of clients with Visible Lesion' : screening_result
            screening_result = screening_result == 'Suspected Cancer' ? 'Number of clients with Suspected Cancer' : screening_result

            # Assigning personal IDs report
            if screening_result.present? && report[:screening_results_hiv_negative].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_negative][screening_result] ||= []
              @report[:screening_results_hiv_negative][screening_result] << person_id
            end
            if screening_result.present? && !report[:screening_results_hiv_negative].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_negative]['Number of clients with Other gynae'&.to_sym] << person_id
            end

            @age_groups.each do |key, value|
              next unless screening_asesment.present?

              @report[:suspects_disaggregated_by_age][key] << person_id if value.include?(age_group) &&
                                                                           screening_asesment == concept('Suspect cancer').concept_id
            end

            if dot_option.present? && report[:total_treated].keys.include?(dot_option&.to_sym)
              @report[:total_treated][dot_option] ||= [] if dot_option.present?
              @report[:total_treated][dot_option] << person_id
            end

            # assiging accurate template value (LEEP) to screening_result instead of (LLETZ/LEEP)
            screening_result = screening_result == 'LLETZ/LEEP' ? 'LEEP' : screening_result

            if tx_option.present? && report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option][tx_option] ||= [] if tx_option.present?
              @report[:total_treated_disaggregated_by_tx_option][tx_option] << person_id
            end

            if tx_option.present? && !report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option]['Other'&.to_sym] << person_id
            end

            # assiging accurate template value (Treatment not available) to screening_result instead of (No treatment)
            screening_result = screening_result == 'Treatment not available' ? 'No treatment' : screening_result

            if referral_reason.present? && report[:referral_reasons].keys.include?(referral_reason&.to_sym)
              @report[:referral_reasons][referral_reason] ||= [] if referral_reason.present?
              @report[:referral_reasons][referral_reason] << person_id
            end
            if referral_reason.present? && !report[:referral_reasons].keys.include?(referral_reason&.to_sym)
              @report[:referral_reasons]['Other gynae'&.to_sym] << person_id
            end

            @age_groups.each do |key, value|
              next unless dot_option.present?

              @report[:total_treated_disaggregated_by_age][key] << person_id if value.include?(age_group)
            end

            @report[:referral_feedback]['With referral feedback'] << person_id if outcome.present?

            if family_planning.present? && report[:family_planning].keys.include?(family_planning&.to_sym)
              @report[:family_planning][family_planning] ||= [] if family_planning.present?
              @report[:family_planning][family_planning] << person_id
            end
            unless report[:family_planning].keys.include?(family_planning&.to_sym)
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
              reason_for_visit.value_coded visit_reason,
              screened_method.value_coded screening_method,
              screened_result.value_coded screening_result,
              referral_reason.value_coded referral_reason,
              hiv_status.value_coded hiv_status,
              dot_option.value_coded dot_option,
              person.person_id,
              cxca_moh_age_group(p.birthdate, DATE(encounter.encounter_datetime)) age_group
            FROM person p
            INNER JOIN encounter e ON e.patient_id = p.person_id
              AND e.program_id = #{program(CXCA_PROGRAM).id} AND e.encounter_datetime >= '#{@start_date}'
              AND e.encounter_datetime <= '#{@end_date}'
              AND e.encounter_type = #{encounter_type(CXCA_TEST).id}
              AND e.voided = 0
            LEFT JOIN obs screened_method ON screened_method.person_id = person.person_id
              AND screened_method.concept_id = #{concept(SCREENING_METHOD).concept_id}
              AND screened_method.voided = 0
              AND screened_method.obs_datetime >= '#{@start_date}'
              AND screened_method.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs screened_result ON screened_result.person_id = person.person_id
            	AND screened_result.concept_id = #{concept(SCREENING_RESULTS).concept_id}
            	AND screened_result.voided = 0
              AND screened_result.obs_datetime >= '#{@start_date}'
              AND screened_result.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs referral_reason ON referral_reason.person_id = person.person_id
            	AND referral_reason.concept_id = #{concept(REFFERAL_REASONS).concept_id}
            	AND referral_reason.voided = 0
              AND referral_reason.obs_datetime >= '#{@start_date}'
              AND referral_reason.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs hiv_status ON hiv_status.person_id = person.person_id
            	AND hiv_status.concept_id = #{concept(HIV_STATUS).concept_id}
            	AND hiv_status.voided = 0
              AND hiv_status.obs_datetime >= '#{@start_date}'
              AND hiv_status.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs dot_option ON dot_option.person_id = person.person_id
            	AND dot_option.concept_id = #{concept(DOT_OPTION).concept_id}
            	AND dot_option.voided = 0
              AND dot_option.obs_datetime >= '#{@start_date}'
              AND dot_option.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs screening_asesment ON screening_asesment.person_id = person.person_id
            	AND screening_asesment.concept_id = #{concept(SCREENING_ASSESMENT).concept_id}
            	AND screening_asesment.voided = 0
              AND screening_asesment.obs_datetime >= '#{@start_date}'
              AND screening_asesment.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs tx_option ON tx_option.person_id = person.person_id
            	AND tx_option.concept_id = #{concept(TX_OPTION).concept_id}
            	AND tx_option.voided = 0
              AND tx_option.obs_datetime >= '#{@start_date}'
              AND tx_option.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs family_planning ON family_planning.person_id = person.person_id
            	AND family_planning.concept_id = #{concept(FAMILY_PLANNING).concept_id}
            	AND family_planning.voided = 0
              AND family_planning.obs_datetime >= '#{@start_date}'
              AND family_planning.obs_datetime <= '#{@end_date}'
            LEFT JOIN obs outcome ON outcome.person_id = person.person_id
            	AND outcome.concept_id = #{concept(OUTCOME).concept_id}
            	AND outcome.voided = 0
              AND outcome.obs_datetime >= '#{@start_date}'
              AND outcome.obs_datetime <= '#{@end_date}'
            INNER JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
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
