# rubocop:disable Metrics/AbcSize
# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Style/Documentation
module CXCAService
  module Reports
    module Moh
      class ScreenedForCxca
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

        def data
          init_report
          map_report query
          report
        end

        private

        def get_concept_name(concept_id)
          concept = ConceptName.find_by_concept_id(concept_id).name if concept_id.present?
          return concept unless concept.blank?

          nil
        end

        def map_report(data)
          @age_groups.each do |key, _value|   
            @report[:suspects_disaggregated_by_age][key] ||= []
            @report[:screened_disaggregated_by_age][key] ||= []
            @report[:total_treated_disaggregated_by_age][key] ||= []
          end
          @report[:screened_disaggregated_by_hiv_status]['Negative'] ||= []

          data.each do |record|
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
              @report[:screened_disaggregated_by_hiv_status]['Negative'] << person_id
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
              @report[:screening_results_hiv_positive][screening_result] << person_id
            end
            if screening_result.present? && !report[:screening_results_hiv_positive].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_positive]['Other gynae'&.to_sym] << person_id
            end
            
            
            if screening_result.present? && report[:screening_results_hiv_negative].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_negative][screening_result] ||= []
              @report[:screening_results_hiv_negative][screening_result] << person_id 
            end
            if screening_result.present? && !report[:screening_results_hiv_negative].keys.include?(screening_result&.to_sym)
              @report[:screening_results_hiv_negative]['Other gynae'&.to_sym] << person_id
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
            
            
            if tx_option.present? && report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option][tx_option] ||= [] if tx_option.present?
              @report[:total_treated_disaggregated_by_tx_option][tx_option] << person_id
            end

            if tx_option.present? && !report[:total_treated_disaggregated_by_tx_option].keys.include?(tx_option&.to_sym)
              @report[:total_treated_disaggregated_by_tx_option]['Other'&.to_sym] << person_id
            end

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
              @report[:family_planning]['Not applicable'&.to_sym] << person_id
            end
          end
        end

        def init_report
          @report = {
            screened_disaggregated_by_age: {},
            screened_disaggregated_by_hiv_status: {
              "Positive NOT on ART": [],
              "Positive on ART": [],
              "Negative": []
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
              "HPV positive": [],
              "HPV negative": [],
              "VIA negative": [],
              "VIA positive": [],
              "PAP Smear normal": [],
              "PAP Smear Abnormal": [],
              "No visible Lesion": [],
              "Visible Lesion": [],
              "Suspected Cancer": [],
              "Other gynae": []
            },
            screening_results_hiv_negative: {
              "HPV positive": [],
              "HPV negative": [],
              "VIA negative": [],
              "VIA positive": [],
              "PAP Smear normal": [],
              "PAP Smear Abnormal": [],
              "No visible Lesion": [],
              "Visible Lesion": [],
              "Suspected Cancer": [],
              "Other gynae": []
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
              'LLETZ/LEEP': [],
              'Other': []
            },
            referral_reasons: {
              "Further Investigation and Management": [],
              "Large Lesion (Greater than 75 percent)": [],
              "Unable to treat client": [],
              "Suspect Cancer": [],
              "Treatment not available": [],
              "Other gynae": []
            },
            total_treated_disaggregated_by_age: {},
            family_planning: {
              'Yes': [],
              'No': [],
              'Not applicable': []
            },
            referral_feedback: {
              "With referral feedback": []
            }
          }
          @age_groups = {
            '< 25 years' => ['<1 year',
                             '1-4 years', '5-9 years',
                             '10-14 years', '15-19 years',
                             '20-24 years'],
            '25-29 years' => ['25-29 years'],
            '30-44 years' => ['30-34 years', '35-39 years',
                              '40-44 years'],
            '45-49 years' => ['45-49 years'],
            '> 49 years' => ['50-54 years', '55-59 years',
                             '60-64 years', '65-69 years',
                             '70-74 years', '75-79 years',
                             '80-84 years', '85-90 years',
                             '90 plus years']
          }
        end

        def query
          ActiveRecord::Base.connection.select_all <<-SQL
					SELECT
						outcome.value_coded, family_planning.value_coded family_planning, tx_option.value_coded tx_option, screening_asesment.value_coded screening_asessment, reason_for_visit.value_coded visit_reason, screened_method.value_coded screening_method, screened_result.value_coded screening_result, referral_reason.value_coded referral_reason, hiv_status.value_coded hiv_status, dot_option.value_coded dot_option, person.person_id, disaggregated_age_group(person.birthdate, DATE(encounter.encounter_datetime)) age_group
						FROM person
						INNER JOIN encounter ON encounter.patient_id = person.person_id
						LEFT JOIN obs screened_method ON screened_method.person_id = person.person_id
							AND screened_method.concept_id = #{concept(SCREENING_METHOD).concept_id}
							AND screened_method.voided = 0
						LEFT JOIN obs screened_result ON screened_result.person_id = person.person_id
							AND screened_result.concept_id = #{concept(SCREENING_RESULTS).concept_id}
							AND screened_result.voided = 0
						LEFT JOIN obs referral_reason ON referral_reason.person_id = person.person_id
							AND referral_reason.concept_id = #{concept(REFFERAL_REASONS).concept_id}
							AND referral_reason.voided = 0
						LEFT JOIN obs hiv_status ON hiv_status.person_id = person.person_id
							AND hiv_status.concept_id = #{concept(HIV_STATUS).concept_id}
							AND hiv_status.voided = 0
						LEFT JOIN obs dot_option ON dot_option.person_id = person.person_id
							AND dot_option.concept_id = #{concept(DOT_OPTION).concept_id}
							AND dot_option.voided = 0
						LEFT JOIN obs screening_asesment ON screening_asesment.person_id = person.person_id
							AND screening_asesment.concept_id = #{concept(SCREENING_ASSESMENT).concept_id}
							AND screening_asesment.voided = 0
						LEFT JOIN obs tx_option ON tx_option.person_id = person.person_id
							AND tx_option.concept_id = #{concept(TX_OPTION).concept_id}
							AND tx_option.voided = 0
						LEFT JOIN obs family_planning ON family_planning.person_id = person.person_id
							AND family_planning.concept_id = #{concept(FAMILY_PLANNING).concept_id}
							AND family_planning.voided = 0
						LEFT JOIN obs outcome ON outcome.person_id = person.person_id
							AND outcome.concept_id = #{concept(OUTCOME).concept_id}
							AND outcome.voided = 0
						INNER JOIN obs reason_for_visit ON reason_for_visit.person_id = person.person_id
							AND reason_for_visit.voided = 0
							AND reason_for_visit.concept_id = #{concept('Reason for visit').concept_id}
						WHERE encounter.encounter_datetime BETWEEN '#{@start_date}' AND '#{@end_date}'
						AND encounter.program_id = #{Program.find_by_name('CxCa Program').program_id}
						GROUP BY person.person_id
          SQL
        end
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength, Style/Documentation, Metrics/AbcSize
