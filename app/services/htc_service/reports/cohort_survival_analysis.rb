
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
          type: 'survival_analysis', start_date: Date.today,
            end_date: Date.today, rebuild: @regenerate)

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
          type: 'survival_analysis', start_date: @start_date.to_date,
            end_date: @end_date.to_date, rebuild: @regenerate)


        qtr = quarter.split(' ')[0]
        results = {}
        years = 1

        years_to_backto = ActiveRecord::Base.connection.select_one <<~SQL
          SELECT
	          TIMESTAMPDIFF(YEAR, DATE(MIN(encounter_datetime)), DATE('#{end_date}')) years
          FROM encounter e WHERE program_id = 1 AND voided = 0;
        SQL

        clinic_start_years = years_to_backto["years"].to_i rescue nil
        clinic_start_years = 10 if clinic_start_years.blank?

        while(years < clinic_start_years) do
          yr = ((quarter.split(' ')[1]).to_i - years)
          set_qtr = "#{qtr} #{yr}"
          qstart_date, qend_date = art_service.generate_start_date_and_end_date(set_qtr)
          results[set_qtr] = {}


		      if age_group == 'General'
		        additional_sql = ' GROUP BY e.patient_id'
		      elsif age_group == 'Children'
		        additional_sql = ' GROUP BY e.patient_id'
		        additional_sql += ' HAVING patient_age < 15'
		      elsif age_group == 'Women'
		        option_Bplus_women_ids = pregnant_and_breastfeeding_women(qstart_date, qend_date)

            option_Bplus_women_ids = [0] if option_Bplus_women_ids.blank?

						additional_sql = ' AND e.patient_id IN (' + "#{option_Bplus_women_ids.join(', ')}" + ')'
		        additional_sql += ' GROUP BY e.patient_id'
		        additional_sql += ' HAVING patient_age >= 15'
		        additional_sql += ' AND gender = "F"'
		      end

          begin
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

          rescue
            return results
          end

          (data || []).each do |r|
            outcome = r['cum_outcome']
            outcome = (outcome.blank? ? 'Unknown' : outcome)

            if results[set_qtr][outcome].blank?
              results[set_qtr][outcome] = {}
              results[set_qtr][outcome][r['qinterval']] = 0
            end
            results[set_qtr][outcome][r['qinterval']] += 1
          end

          years+= 1
        end

        if age_group == 'Women'
          append_last_six_months(quarter, results, end_date)
        end

        return results
      end

      def pregnant_and_breastfeeding_women(start_date, end_date)
        patient_ids = []

        patients = ActiveRecord::Base.connection.select_all <<EOF
        SELECT
          e.*, patient_reason_for_starting_art_text(e.patient_id) reason
        FROM temp_earliest_start_date e
        WHERE date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
        AND gender IN('F','Female') GROUP BY e.patient_id
        HAVING reason LIKE '%pregnant%' OR reason LIKE '%breast%';
EOF

				(patients || []).each do |aRow|
				  patient_ids << aRow['patient_id'].to_i
				end

        concept_ids = []
        ConceptName.where(name: 'Breastfeeding').select do |c|
          concept_ids << c.concept_id
        end
        concept_ids << ConceptName.find_by_name('Patient pregnant').concept_id
        concept_ids << ConceptName.find_by_name('Is patient pregnant?').concept_id
        concept_ids << ConceptName.find_by_name('Is patient breast feeding?').concept_id
        yes_concept_id = ConceptName.find_by_name('Yes').concept_id

        patients = ActiveRecord::Base.connection.select_all <<EOF
        SELECT
          e.*, patient_reason_for_starting_art_text(e.patient_id) reason
        FROM temp_earliest_start_date e
        INNER JOIN obs ON obs.person_id = e.patient_id
        WHERE date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
        AND gender IN('F','Female') AND obs.voided = 0
        AND DATE(obs_datetime) = DATE(earliest_start_date)
        AND obs.concept_id IN(#{concept_ids.join(',')})
        AND value_coded = #{yes_concept_id} GROUP BY e.patient_id
        HAVING reason LIKE '%Lymphocyte count below threshold with who stage%'
        ORDER BY obs_datetime DESC;
EOF

        pregnant_and_breastfeeding_clients = []

				(patients || []).each do |aRow|
          pregnant_and_breastfeeding_clients << aRow['patient_id'].to_i
        end

				return (patient_ids + pregnant_and_breastfeeding_clients).uniq
      end

      def append_last_six_months(quarter, results, end_date)
        art_service = ARTService::Reports::CohortDisaggregated.new(name: 'survival_analysis',
          type: 'survival_analysis', start_date: @start_date.to_date,
            end_date: @end_date.to_date, rebuild: @regenerate)

        qstart_date, qend_date = art_service.generate_start_date_and_end_date(quarter)
        qstart_date = qstart_date - 6.month
        qend_date = qend_date - 6.month
        #set_qtr = "Q#{quarter.split(' ')[0][1..1].to_i - 2} #{qend_date.year}"
        set_qtr = (quarter[1..1].to_i - 2)

        set_qtr = (set_qtr == 0 ? 4 : set_qtr)
        set_qtr = (set_qtr == -1 ? 3 : set_qtr)
        set_qtr = (set_qtr == -2 ? 2 : set_qtr)
        set_qtr = "Q#{set_qtr} #{qend_date.year}"

				option_Bplus_women_ids = pregnant_and_breastfeeding_women(qstart_date, qend_date)
				option_Bplus_women_ids = [0] if option_Bplus_women_ids.blank?

        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT
          cum_outcome, timestampdiff(month, DATE('#{qend_date}'), DATE('#{end_date}')) qinterval,
          timestampdiff(year, DATE(e.birthdate), DATE('#{end_date}')) AS patient_age,
          e.gender
        FROM temp_earliest_start_date e
        INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
        WHERE date_enrolled BETWEEN '#{qstart_date.strftime('%Y-%m-%d')}'
        AND '#{qend_date.strftime('%Y-%m-%d')}' AND gender = 'F' AND e.patient_id IN (#{option_Bplus_women_ids.join(', ')});
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
