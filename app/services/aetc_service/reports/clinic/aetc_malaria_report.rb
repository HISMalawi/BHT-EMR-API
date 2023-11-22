# frozen_string_literal: true

module AetcService
  module Reports
    module Clinic
      # Aetc Malaria Report
      class AetcMalariaReport
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date
          @end_date = end_date
        end

        def fetch_report
          malaria_report
        end

        def registration
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              malaria_report('', '', '', '', '', c.name, p.birthdate, '#{@end_date.to_date}') as malaria_data,
              o.person_id
            FROM encounter e
            INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type AND et.retired = 0 AND et.name = 'PATIENT REGISTRATION'
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Type of visit') AND o.value_coded IS NOT NULL
            INNER JOIN concept_name c ON c.concept_id = o.value_coded AND c.voided = 0 -- AND c.name IN ('New patient', 'Referred')
            INNER JOIN person p ON p.person_id = e.patient_id AND p.voided = 0
            WHERE e.encounter_datetime BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            GROUP BY o.person_id
          SQL
        end

        def malaria_report
          @malaria_data = malaria_data

          build_malaria_hash
        end

        def build_malaria_hash
          confrim_non_pregnant_5more = get_ids('> 5yrs', 'confrim_non_pregnant', '')
          confrim_non_pregnant_5less = get_ids('< 5yrs', 'confrim_non_pregnant', '')
          presume_non_pregnant_5more = get_ids('> 5yrs', 'presume_non_pregnant', '') - confrim_non_pregnant_5more
          presume_non_pregnant_5less = get_ids('< 5yrs', 'presume_non_pregnant', '') - confrim_non_pregnant_5less
          confirm_pregnant_5more     = get_ids('> 5yrs', 'confirm_pregnant', '')
          confirm_pregnant_5less     = get_ids('< 5yrs', 'confirm_pregnant', '')
          presume_pregnant_5more     = get_ids('> 5yrs', 'presume_pregnant', '') - confirm_pregnant_5more
          presume_pregnant_5less     = get_ids('< 5yrs', 'presume_pregnant', '') - confirm_pregnant_5less
          total_OPD_malaria_cases_5more = confrim_non_pregnant_5more + presume_non_pregnant_5more + confirm_pregnant_5more + presume_pregnant_5more
          total_OPD_malaria_cases_5less = confrim_non_pregnant_5less + presume_non_pregnant_5less + confirm_pregnant_5less + presume_pregnant_5less

          suspected_malaria_mRDT_less_5yrs       = get_ids('< 5yrs', 'negative_MRDT', '')
          suspected_malaria_mRDT_more_5yrs       = get_ids('> 5yrs', 'negative_MRDT', '')
          suspected_malaria_microscopy_less_5yrs = get_ids('< 5yrs', 'negative_Malaria film', '')
          suspected_malaria_microscopy_more_5yrs = get_ids('> 5yrs', 'negative_Malaria film', '')
          total_suspected_malaria_5more = suspected_malaria_mRDT_more_5yrs + suspected_malaria_microscopy_more_5yrs + presume_non_pregnant_5more + presume_pregnant_5more
          total_suspected_malaria_5less = suspected_malaria_mRDT_less_5yrs + suspected_malaria_microscopy_less_5yrs + presume_non_pregnant_5less + presume_pregnant_5less

          {
            confrim_non_pregnant_more_5yrs: confrim_non_pregnant_5more,
            confrim_non_pregnant_less_5yrs: confrim_non_pregnant_5less,
            presume_non_pregnant_more_5yrs: presume_non_pregnant_5more,
            presume_non_pregnant_less_5yrs: presume_non_pregnant_5less,
            confirm_pregnant_less_5yrs: confirm_pregnant_5less,
            confirm_pregnant_more_5yrs: confirm_pregnant_5more,
            presume_pregnant_less_5yrs: presume_pregnant_5less,
            presume_pregnant_more_5yrs: presume_pregnant_5more,
            total_OPD_malaria_cases_more_5yrs: total_OPD_malaria_cases_5more,
            total_OPD_malaria_cases_less_5yrs: total_OPD_malaria_cases_5less,
            total_OPD_attendance: registration,
            confirmed_malaria_treatment_failure_less_5yrs: get_ids('< 5yrs', 'confirmed_malaria_treatment_failure', ''),
            confirmed_malaria_treatment_failure_more_5yrs: get_ids('> 5yrs', 'confirmed_malaria_treatment_failure', ''),
            presumed_malaria_LA_less_5yrs: get_ids('< 5yrs', 'presume',
                                                   'Lumefantrine') - get_ids('< 5yrs', 'confrim', 'Lumefantrine'),
            presumed_malaria_LA_more_5yrs: get_ids('> 5yrs', 'presume',
                                                   'Lumefantrine') - get_ids('> 5yrs', 'confrim', 'Lumefantrine'),
            presumed_malaria_ASAQ_less_5yrs: get_ids('< 5yrs', 'presume',
                                                     'ASAQ') - get_ids('< 5yrs', 'confrim', 'ASAQ'),
            presumed_malaria_ASAQ_more_5yrs: get_ids('> 5yrs', 'presume',
                                                     'ASAQ') - get_ids('> 5yrs', 'confrim', 'ASAQ'),
            confirmed_malaria_LA_less_5yrs: get_ids('< 5yrs', 'confrim', 'Lumefantrine'),
            confirmed_malaria_LA_more_5yrs: get_ids('> 5yrs', 'confrim', 'Lumefantrine'),
            confirmed_malaria_ASAQ_less_5yrs: get_ids('< 5yrs', 'confrim', 'ASAQ'),
            confirmed_malaria_ASAQ_more_5yrs: get_ids('> 5yrs', 'confrim', 'ASAQ'),
            suspected_malaria_mRDT_less_5yrs:,
            suspected_malaria_mRDT_more_5yrs:,
            positive_malaria_mRDT_less_5yrs: get_ids('< 5yrs', 'positive_MRDT', ''),
            positive_malaria_mRDT_more_5yrs: get_ids('> 5yrs', 'positive_MRDT', ''),
            suspected_malaria_microscopy_less_5yrs:,
            suspected_malaria_microscopy_more_5yrs:,
            positive_malaria_microscopy_less_5yrs: get_ids('< 5yrs', 'positive_Malaria film', ''),
            positive_malaria_microscopy_more_5yrs: get_ids('> 5yrs', 'positive_Malaria film', ''),
            total_suspected_malaria_cases_less_5yrs: total_suspected_malaria_5less,
            total_suspected_malaria_cases_more_5yrs: total_suspected_malaria_5more,
            LA_1X6: get_ids('', '', 'Lumefantrine  Arthemether 1  6'),
            LA_2X6: get_ids('', '', 'Lumefantrine  Arthemether 2  6'),
            LA_3X6: get_ids('', '', 'Lumefantrine  Arthemether 3  6'),
            LA_4X6: get_ids('', '', 'Lumefantrine  Arthemether 4  6'),
            sp: get_ids('', '', 'SP'),
            ASAQ_25mg: get_ids('', '', 'ASAQ 25mg/67.5mg 3 tablets'),
            ASAQ_50mg: get_ids('', '', 'ASAQ 50mg/135mg 3 tablets'),
            ASAQ_100mg_3tabs: get_ids('', '', 'ASAQ 100mg/270mg 3 tablets'),
            ASAQ_100mg_6tabs: get_ids('', '', 'ASAQ 100mg/270mg 6 tablets')
          }
        end

        def get_ids(age_range, condition_name, drug_name)
          array_id = []

          @malaria_data.select do |element|
            next unless (element.match?(age_range) && element.match?(condition_name) && drug_name == '') ||
                        (element.match?(age_range) && element.match?(condition_name) && element.gsub(/[()]/,
                                                                                                     '').match?(drug_name) && drug_name != '' && age_range != '') ||
                        (age_range == '' && element.gsub(/[()+x]/, '').match?(drug_name) && !element.match?(','))

            array_id << @malaria_data[element]
          end
          array_id.flatten
        end

        private

        def malaria_data
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
                malaria_report(obs.order_id,obs.value_text,obs.value_coded,obs.person_id,DATE(obs_datetime),c.name,p.birthdate,'#{@end_date.to_date}') as malaria_data,
                obs.person_id
            FROM obs
            INNER JOIN concept_name c ON c.concept_id = obs.concept_id AND c.voided = 0 AND c.name IN ('Amount dispensed', 'MRDT', 'Malaria film', 'Malaria Species', 'Primary diagnosis')
            INNER JOIN person p ON p.person_id = obs.person_id AND p.voided = 0
            INNER JOIN encounter e ON e.encounter_id = obs.encounter_id AND e.voided = 0
            WHERE
                obs.obs_datetime BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                AND obs.voided = 0
            GROUP BY obs.person_id, malaria_data HAVING malaria_data IS NOT NULL
          SQL
        end
      end
    end
  end
end
