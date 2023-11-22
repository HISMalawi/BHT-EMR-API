# frozen_string_literal: true

module SpineService
  module Reports
    module Clinic
      class DiagnosisReport
        include ModelUtils
        attr_reader :start_date, :end_date

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
          @end_date = end_date.to_date.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
        end

        def fetch_report
          data = Encounter.joins("INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id IN(#{concept('Primary diagnosis').id}, #{concept('Secondary diagnosis').id}) AND obs.voided = 0")
                          .joins('INNER JOIN person p ON p.person_id = encounter.patient_id AND p.voided = 0')
                          .joins('INNER JOIN concept_name c ON c.concept_id = obs.value_coded AND c.voided = 0')
                          .where('encounter_datetime BETWEEN ? AND ? AND encounter_type = ?', @start_date, @end_date, encounter_type('diagnosis').id)
                          .group('obs.person_id, obs.value_coded, DATE(obs.obs_datetime)')
                          .select("encounter.encounter_type, p.person_id, obs.value_coded, p.gender,
                                  opd_disaggregated_age_group(p.birthdate,'#{end_date}') as age_group, c.name")

          create_diagnosis_hash(data)
        end

        def create_diagnosis_hash(data)
          records = {}
          (data || []).each do |record|
            age_group = record['age_group'].blank? ? 'Unknown' : record['age_group']
            gender = begin
              (if record['gender'].match(/f/i)
                 'F'
               else
                 (record['gender'].match(/m/i) ? 'M' : 'Unknown')
               end)
            rescue StandardError
              'Unknown'
            end
            patient_id = record['person_id']
            diagnosis = record['name']

            records[diagnosis] = {} if records[diagnosis].blank?

            records[diagnosis][gender] = {} if records[diagnosis][gender].blank?

            records[diagnosis][gender][age_group] = [] if records[diagnosis][gender][age_group].blank?

            records[diagnosis][gender][age_group] << patient_id
          end

          records
        end
      end
    end
  end
end
