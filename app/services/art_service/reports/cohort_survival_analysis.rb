
# frozen_string_literal: true

module ARTService
  module Reports
    class CohortSurvivalAnalysis
      def initialize(name:, type:, start_date:, end_date:, regenerate:)
        @name = name
        @type = type
        @start_date = start_date
        @end_date = end_date
        @regenerate = regenerate
      end

      def survival_analysis(quarter, age_group)
        art_service = ARTService::Reports::CohortDisaggregated.new(name: 'survival_analysis', 
          type: 'survival_analysis', start_date: Date.today, end_date: Date.today)
        
        start_date, end_date = art_service.generate_start_date_and_end_date(quarter) 
        art_service = ARTService::Reports::CohortBuilder.new()
        if @regenerate
          art_service.create_tmp_patient_table
          art_service.load_data_into_temp_earliest_start_date(end_date)
          art_service.update_cum_outcome(end_date) 
        end
        
        quarters = []
        no_data = false
        art_service = ARTService::Reports::CohortDisaggregated.new(name: 'survival_analysis', 
          type: 'survival_analysis', start_date: Date.today, end_date: Date.today)
        
        qtr = quarter.split(' ')[0]
        results = {}
        years = 1
        

        if age_group == 'General'
          additional_sql = ' GROUP BY e.patient_id;'
        elsif age_group == 'Children'
          additional_sql = ' GROUP BY e.patient_id'
          additional_sql += ' HAVING patient_age < 15'
        elsif age_group == 'Women'
          additional_sql = ' GROUP BY e.patient_id'
          additional_sql += ' HAVING patient_age >= 15'
          additional_sql += ' AND gender = "F"'
        end


        while(!no_data) do 
          yr = ((quarter.split(' ')[1]).to_i - years)
          set_qtr = "#{qtr} #{yr}"
          qstart_date, qend_date = art_service.generate_start_date_and_end_date(set_qtr)
          results[set_qtr] = {}

          data = ActiveRecord::Base.connection.select_all <<EOF
          SELECT 
            cum_outcome, timestampdiff(month, DATE('#{qend_date}'), DATE('#{end_date}')) qinterval,
            timestampdiff(year, DATE(e.birthdate), DATE('#{end_date}')) AS patient_age,
            e.gender 
          FROM temp_earliest_start_date e
          INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
          WHERE date_enrolled BETWEEN '#{qstart_date.strftime('%Y-%m-%d')}'
          AND '#{qend_date.strftime('%Y-%m-%d')}'
          #{additional_sql};
EOF

          (data || []).each do |r|
            outcome = r['cum_outcome']
            outcome = (outcome.blank? ? 'Unknown' : outcome)

            if results[set_qtr][outcome].blank?
              results[set_qtr][outcome] = {}
              results[set_qtr][outcome][r['qinterval']] = 0
            end
            results[set_qtr][outcome][r['qinterval']] += 1
          end

          no_data = true if data.blank?
          years+= 1
        end
        
        if age_group == 'Women'
          append_last_six_months(quarter, results, end_date)
        end
         
        return results
      end

      def append_last_six_months(quarter, results, end_date)
        art_service = ARTService::Reports::CohortDisaggregated.new(name: 'survival_analysis', 
          type: 'survival_analysis', start_date: Date.today, end_date: Date.today)
        
        qstart_date, qend_date = art_service.generate_start_date_and_end_date(quarter)
        qstart_date = qstart_date - 6.month
        qend_date = qend_date - 6.month
        #set_qtr = "Q#{quarter.split(' ')[0][1..1].to_i - 2} #{qend_date.year}"
        set_qtr = (quarter[1..1].to_i - 2)

        set_qtr = (set_qtr == 0 ? 4 : set_qtr)
        set_qtr = (set_qtr == -1 ? 3 : set_qtr)
        set_qtr = (set_qtr == -2 ? 2 : set_qtr)
        set_qtr = "Q#{set_qtr} #{qend_date.year}"

        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT 
          cum_outcome, timestampdiff(month, DATE('#{qend_date}'), DATE('#{end_date}')) qinterval,
          timestampdiff(year, DATE(e.birthdate), DATE('#{end_date}')) AS patient_age,
          e.gender 
        FROM temp_earliest_start_date e
        INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
        WHERE date_enrolled BETWEEN '#{qstart_date.strftime('%Y-%m-%d')}'
        AND '#{qend_date.strftime('%Y-%m-%d')}' AND gender = 'F';
EOF

        (data || []).each do |r|
          outcome = r['cum_outcome']
          outcome = (outcome.blank? ? 'Unknown' : outcome)

          if results[set_qtr].blank?
            results[set_qtr] = {}
            results[set_qtr][outcome] = {}
            results[set_qtr][outcome][r['qinterval']] = 0
          elsif results[set_qtr][outcome].blank?
            results[set_qtr][outcome] = {}
            results[set_qtr][outcome][r['qinterval']] = 0
          end
          
          puts "######### #{r['qinterval']}"  
          results[set_qtr][outcome][r['qinterval']] += 1

        end
        
        return results      
      end




    end
  end

end
