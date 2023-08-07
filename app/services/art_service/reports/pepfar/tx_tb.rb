# rubocop:disable Metrics/BlockLength
module ARTService
  module Reports
    module Pepfar
      class TxTB
        attr_accessor :start_date, :end_date, :report, :rebuild_outcomes

        include Utils

        SCREENING_QUESTIONS = ['Fever', 'Cough', 'Night sweats', 'Weight loss / Failure to thrive / malnutrition'].freeze

        def initialize(start_date:, end_date:, **kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
          @rebuild_outcomes = kwargs[:rebuild_outcomes] || false
        end

        def find_report
          init_report
          tx_curr = find_patients_alive_and_on_art
          tx_curr.each { |patient| report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['person_id'] }
          screened = patients_screened_for_tb
          pepfar_age_groups.each do |age_group|
            screened.each do |patient|

              next unless patient['age_group'] == age_group

              start_date = patient['earliest_start_date']
              enrollment_date = patient['date_enrolled']
              tb_status_id = patient['tb_status']
              gender = patient['gender'].to_sym
              screened_pos = patient['screened_pos']
              
              next unless tb_status_id.present? && enrollment_date.present?

              tb_status_name = ConceptName.find_by_concept_id(tb_status_id).name
              key_prefix = new_on_art(start_date, enrollment_date) ? :new : :prev
              
              started_tb_key = :"started_tb_#{key_prefix}"
              sceen_pos_key = :"sceen_pos_#{key_prefix}"
              sceen_neg_key = :"sceen_neg_#{key_prefix}"

              if screened_pos == 1
                report[age_group][gender][sceen_pos_key] << patient['person_id']
              else
                if ['RX', 'Confirmed TB on treatment'].include?(tb_status_name)
                  report[age_group][gender][started_tb_key] << patient['person_id']
                  report[age_group][gender][sceen_pos_key] << patient['person_id']
                else
                  report[age_group][gender][sceen_neg_key] << patient['person_id']
                end
              end
            end
          end
          report
        end

        def init_report
          @report = pepfar_age_groups.each_with_object({}) do |age_group, report|
            %i[M F].collect do |gender|
              report[age_group] ||= {}
              report[age_group][gender] = {
                tx_curr: [],
                sceen_pos_new: [],
                sceen_neg_new: [],
                started_tb_new: [],
                sceen_pos_prev: [],
                sceen_neg_prev: [],
                started_tb_prev: []
              }
            end
          end
        end

        def find_patients_alive_and_on_art
          patients = PatientsAliveAndOnTreatment
            .new(start_date: start_date, end_date: end_date, outcomes_definition: 'pepfar', rebuild_outcomes: false)
            .query&.collect { |patient| patient['patient_id'] }
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT p.person_id, p.gender, disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group
            FROM person p
            WHERE p.person_id IN (#{patients.join(',')})
          SQL
        end

        def new_on_art(earliest_start_date, min_date)
          med_start_date = min_date.to_date
          med_end_date = (earliest_start_date.to_date + 90.day).to_date

          return true if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date

          false
        end

        def patients_screened_for_tb
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT p.person_id, p.gender, disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group, earliest_start_date_at_clinic(p.person_id) AS earliest_start_date,
            date_antiretrovirals_started(p.person_id, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS date_enrolled,
            MIN(CASE WHEN o.value_coded = 1065 THEN true ELSE false END) AS screened_pos, tb_status.value_coded as tb_status
            FROM person p
            INNER JOIN obs tb_status ON tb_status.person_id = p.person_id
              AND tb_status.voided = 0
              AND tb_status.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            LEFT JOIN (
              SELECT
                person_id,
                value_coded
              FROM
                obs
              WHERE
                obs_datetime BETWEEN DATE(#{ActiveRecord::Base.connection.quote(start_date.to_date)}) AND DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})
                AND concept_id IN (#{ConceptName.where(name: SCREENING_QUESTIONS).select(:concept_id).map(&:concept_id).join(',')})
                AND voided = 0
            ) o ON o.person_id = p.person_id
            GROUP BY person_id
          SQL
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
