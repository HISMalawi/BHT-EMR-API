# frozen_string_literal: true

module SpineService
  module Reports
    module Clinic
      class DiagnosisReport
        include ModelUtils
        attr_reader :start_date, :end_date
        primary_diagnosis = 6542
        secondary_diagnosis = 6543
        cellphoneNumberId = 12

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def fetch_report
          data = Encounter.joins("INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id IN(#{primary_diagnosis}, #{secondary_diagnosis}) AND obs.voided = 0")
                          .joins("INNER JOIN person p ON p.person_id = encounter.patient_id")
                          .joins("LEFT JOIN person_name n ON n.person_id = encounter.patient_id AND n.voided = 0")
                          .joins("LEFT JOIN person_attribute z ON z.person_id = encounter.patient_id AND z.person_attribute_type_id = #{cellphoneNumberId}")
                          .joins("LEFT JOIN person_address a ON a.person_id = encounter.patient_id")
                          .joins("INNER JOIN concept_name c ON c.concept_id = obs.value_coded")
                          .where('encounter_datetime BETWEEN ? AND ? AND encounter_type = ?', @start_date, @end_date, encounter_type('Outpatient diagnosis').id)
                          .group('obs.person_id, obs.value_coded, DATE(obs.obs_datetime)')
                          .select("encounter.encounter_type, n.given_name, n.family_name, n.person_id, obs.value_coded, p.gender,
                                  a.state_province district, a.township_division ta, a.city_village village, z.value,
                                  opd_disaggregated_age_group(p.birthdate,'#{end_date}') as age_group, c.name")

          create_diagnosis_hash(data)
        end

        def create_diagnosis_hash(data)
          records = {}
          (data || []).each do |record|
            age_group = record['age_group'].blank? ? "Unknown" : record['age_group']
            gender = (record['gender'].match(/f/i) ? "F" : (record['gender'].match(/m/i) ? "M" : "Unknown")) rescue "Unknown"
            patient_id = record['person_id']
            diagnosis = record['name']

            if records[diagnosis].blank?
              records[diagnosis] = {}
            end

            if records[diagnosis][gender].blank?
              records[diagnosis][gender] = {}
            end

            if records[diagnosis][gender][age_group].blank?
              records[diagnosis][gender][age_group] = []
            end

            records[diagnosis][gender][age_group] << patient_id

          end

          records
        end
      end
    end
  end
end