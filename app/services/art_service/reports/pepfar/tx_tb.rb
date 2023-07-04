# rubocop:disable Metrics/BlockLength
module ArtService
  module Reports
    module Pepfar
      class TxTb
        attr_accessor :start_date, :end_date, :report

        include Utils

        def initialize(start_date:, end_date:, **_kwargs)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def find_report
          init_report
          tx_curr = find_patients_alive_and_on_art
          tx_curr.each { |patient| report[patient['age_group']][patient['gender'].to_sym][:tx_curr] << patient['patient_id'] }
          screened = tb_screened(tx_curr.map { |patient| patient['patient_id'] })
          pepfar_age_groups.each do |age_group|
            screened.each do |patient|

              next unless patient['age_group'] == age_group

              start_date = patient['earliest_start_date']
              enrollment_date = patient['date_enrolled']
              tb_status_id = patient['tb_status']
              gender = patient['gender'].to_sym

              tb_status_name = ConceptName.find_by_concept_id(tb_status_id).name
              next unless tb_status_name.present?

              key_prefix = new_on_art(start_date, enrollment_date) ? :new : :prev

              started_tb_key = :"started_tb_#{key_prefix}"
              sceen_pos_key = :"sceen_pos_#{key_prefix}"
              sceen_neg_key = :"sceen_neg_#{key_prefix}"
              if ['RX', 'Confirmed TB on treatment'].include?(tb_status_name)
                report[age_group][gender][started_tb_key] << patient['person_id']
              elsif ['TB Suspected', 'Confirmed TB NOT on treatment', 'sup', 'Norx'].include?(tb_status_name)
                report[age_group][gender][sceen_pos_key] << patient['person_id']
              elsif tb_status_name == 'TB NOT suspected'
                report[age_group][gender][sceen_neg_key] << patient['person_id']
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

        def arv_concepts
          @arv_concepts ||= ConceptSet.where(concept_set: ConceptName.where(name: 'Antiretroviral drugs')
                                                                    .select(:concept_id))
                                      .collect(&:concept_id).join(',')
        end

        def find_patients_alive_and_on_art
          ActiveRecord::Base.connection.select_all <<~SQL
          SELECT pp.patient_id, p.gender, coalesce(o.value_datetime, min(art_order.start_date)) art_start_date, disaggregated_age_group(p.birthdate, DATE('#{end_date.to_date}')) age_group
          FROM patient_program pp
          INNER JOIN person p ON p.person_id = pp.patient_id AND p.voided = 0
          INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id AND ps.voided = 0 AND ps.state = 7 -- ON ART
          INNER JOIN orders art_order ON art_order.patient_id = pp.patient_id
            AND art_order.start_date >= DATE('#{start_date}')
            AND art_order.start_date < DATE('#{end_date}') + INTERVAL 1 DAY
            AND art_order.voided = 0
            AND art_order.order_type_id = 1 -- Drug order
            AND art_order.concept_id IN (#{arv_concepts})
          INNER JOIN drug_order do ON do.order_id = art_order.order_id AND do.quantity > 0
          LEFT JOIN encounter e ON e.patient_id = pp.patient_id
            AND e.encounter_type = 9 -- HIV CLINIC REGISTRATION
            AND e.voided = 0
            AND e.encounter_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            AND e.program_id = 1 -- HIV program
          LEFT JOIN obs o ON o.person_id = pp.patient_id
            AND o.concept_id = 2516 -- ART start date
            AND o.encounter_id = e.encounter_id
            AND o.voided = 0
          WHERE pp.patient_id NOT IN (
            SELECT o.patient_id
            FROM orders o
            INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0
            WHERE o.order_type_id = 1 -- Drug order
              AND o.voided  = 0
              AND o.concept_id IN (#{arv_concepts})
              AND o.start_date < DATE('#{start_date}')
            GROUP BY o.patient_id
          )
          AND pp.program_id = 1 -- HIV program
          GROUP BY pp.patient_id
          SQL
        end

        def new_on_art(earliest_start_date, min_date)
          med_start_date = min_date.to_date
          med_end_date = (earliest_start_date.to_date + 90.day).to_date

          return true if med_start_date >= earliest_start_date.to_date && med_start_date < med_end_date

          false
        end

        def tb_screened(patient_ids)
          return [] if patient_ids.blank?

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT DISTINCT p.person_id, p.gender, o.value_coded AS tb_status, disaggregated_age_group(p.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS age_group, earliest_start_date_at_clinic(p.person_id) AS earliest_start_date,
            date_antiretrovirals_started(p.person_id, DATE(#{ActiveRecord::Base.connection.quote(end_date.to_date)})) AS date_enrolled
            FROM person p
            INNER JOIN obs o ON o.person_id = p.person_id and o.voided = 0
            WHERE o.concept_id = #{ConceptName.find_by_name('TB status').concept_id}
            AND p.person_id IN(#{patient_ids.join(",")})
          SQL
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
