module ARTService
  module Reports
    module Pepfar
      class TxMl
        attr_reader :start_date, :end_date

        include Utils

        def initialize(start_date:, end_date:)
          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = end_date.to_date.strftime('%Y-%m-%d 23:59:59')
        end

        def data
          tx_ml
        end

        private

        def tx_ml
          data = {}
          tx_curr = potential_tx_ml_clients
          tx_new  = new_potential_tx_ml_clients
          patient_ids = []
          earliest_start_dates = {}

          (tx_curr || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            patient_ids << patient_id
            earliest_start_dates[patient_id] = begin
              pat['earliest_start_date'].to_date
            rescue StandardError
              pat['date_enrolled'].to_date
            end
          end

          (tx_new || []).each do |pat|
            patient_id = pat['patient_id'].to_i
            patient_ids << patient_id
            patient_ids = patient_ids.uniq
            earliest_start_dates[patient_id] = begin
              pat['earliest_start_date'].to_date
            rescue StandardError
              pat['date_enrolled'].to_date
            end
          end

          (tx_new || []).each do |pat|
            patient_ids << pat['patient_id']
            patient_ids = patient_ids.uniq
          end

          return [] if patient_ids.blank?

          filtered_patients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.person_id patient_id, birthdate, gender,
              pepfar_patient_outcome(p.person_id, date('#{end_date}')) outcome,
              disaggregated_age_group(p.birthdate, DATE('#{end_date}')) age_group
            FROM person p
            WHERE p.person_id IN(#{patient_ids.join(',')})
            GROUP BY p.person_id
          SQL

          (filtered_patients || []).each do |pat|
            outcome = pat['outcome']
            next if outcome == 'On antiretrovirals'

            patient_id = pat['patient_id'].to_i
            gender = begin
              pat['gender'].first.upcase
            rescue StandardError
              'Unknown'
            end
            age_group = pat['age_group']

            if data[age_group].blank?
              data[age_group] = {}
              data[age_group][gender] = [[], [], [], [], [], []]
            elsif data[age_group][gender].blank?
              data[age_group][gender] = [[], [], [], [], [], []]
            end

            case outcome
            when 'Defaulted'
              def_months = defaulter_period(patient_id, earliest_start_dates[patient_id])
              if def_months < 3
                data[age_group][gender][1] << patient_id
              elsif def_months <= 5
                data[age_group][gender][2] << patient_id
              elsif def_months > 5
                data[age_group][gender][3] << patient_id
              end
            when 'Patient died'
              data[age_group][gender][0] << patient_id
            when /Stopped/i
              data[age_group][gender][5] << patient_id
            when 'Patient transferred out'
              data[age_group][gender][4] << patient_id
            end
          end

          data
        end

        def potential_tx_ml_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.patient_id AS patient_id,
              pe.birthdate,
              pe.gender,
              CAST(patient_date_enrolled(p.patient_id) AS date) AS date_enrolled,
              date_antiretrovirals_started(p.patient_id, MIN(s.start_date)) AS earliest_start_date
            FROM patient_program p
            INNER JOIN person pe ON pe.person_id = p.patient_id AND pe.voided = 0
            INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id AND s.voided = 0 AND s.state = 7
            WHERE p.program_id = 1
              AND s.state = 7
              AND DATE(s.start_date) < '#{start_date.to_date}'
              AND pepfar_patient_outcome(p.patient_id, DATE('#{start_date.to_date - 1.day}')) = 'On antiretrovirals'
              AND pe.person_id NOT IN (#{drug_refills_and_external_consultation_list})
            GROUP BY p.patient_id
            HAVING date_enrolled IS NOT NULL AND DATE(date_enrolled) < '#{start_date.to_date}';
          SQL
        end

        def new_potential_tx_ml_clients
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              p.patient_id AS patient_id,
              pe.birthdate,
              pe.gender,
              cast(patient_date_enrolled(p.patient_id) as date) AS date_enrolled,
              date_antiretrovirals_started(p.patient_id, min(s.start_date)) AS earliest_start_date
            FROM patient_program p
            INNER JOIN person pe ON pe.person_id = p.patient_id AND pe.voided = 0
            INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id AND s.voided = 0 AND s.state = 7
            WHERE p.program_id = 1
              AND DATE(s.start_date) BETWEEN DATE('#{start_date}') AND DATE('#{end_date}')
              AND pe.person_id NOT IN (#{drug_refills_and_external_consultation_list})
            GROUP BY p.patient_id
            HAVING date_enrolled IS NOT NULL AND date_enrolled BETWEEN DATE('#{start_date}') AND DATE('#{end_date}');
          SQL
        end

        def defaulter_period(patient_id, earliest_start_date)
          defaulter_date = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT current_pepfar_defaulter_date(#{patient_id}, '#{end_date}') def_date;
          SQL

          defaulter_date = defaulter_date['def_date'].to_date rescue end_date.to_date
          days_gone = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT TIMESTAMPDIFF(MONTH, DATE('#{earliest_start_date}'), DATE('#{defaulter_date}')) months;
          SQL

          days_gone['months'].to_i
        end
      end
    end
  end
end
