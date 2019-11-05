
module ARTService
  module Reports

    class CohortDisaggregatedAdditions
      
      def initialize(start_date:, end_date:, gender:, age_group:)
        @start_date = start_date
        @end_date = end_date
        @gender = gender
        @age_group = age_group
      end

      def screened_for_tb
        return screened_for_tb_female_client('FP') if @gender == "pregnant"
        return screened_for_tb_female_client('FNP') if @gender == "fnp"
        return screened_for_tb_female_client('FBf') if @gender == "breastfeeding"

        gender = @gender.first.upcase  
        results = ActiveRecord::Base.connection.select_all <<EOF
        SELECT 
          e.patient_id, cohort_disaggregated_age_group(e.birthdate, DATE('#{@end_date}')) age_group
        FROM temp_earliest_start_date e 
        INNER JOIN temp_patient_outcomes USING(patient_id)
        WHERE cum_outcome = 'On antiretrovirals' AND LEFT(gender,1) = '#{gender}'
        GROUP BY e.patient_id HAVING  age_group = '#{@age_group}';
EOF
                                                    
        patient_ids = []
        (results || []).each do |r|
          patient_ids << r['patient_id'].to_i
        end

        return tb_screened(patient_ids)
      end
      
      def clients_given_ipt
        return female_clients_given_ipt('FP') if @gender == "pregnant"
        return female_clients_given_ipt('FNP') if @gender == "fnp"
        return female_clients_given_ipt('FBf') if @gender == "breastfeeding"

        gender = @gender.first.upcase  

        patient_ids = []
        results = ActiveRecord::Base.connection.select_all <<EOF
        SELECT 
          e.patient_id, cohort_disaggregated_age_group(e.birthdate, DATE('#{@end_date}')) age_group
        FROM temp_earliest_start_date e 
        INNER JOIN temp_patient_outcomes USING(patient_id)
        WHERE cum_outcome = 'On antiretrovirals' AND LEFT(gender,1) = '#{gender}'
        GROUP BY e.patient_id HAVING  age_group = '#{@age_group}';
EOF
                                                    
        (results || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?
        return given_ipt(patient_ids)
      end

      private 

      def given_ipt(patient_ids)
        return [] if patient_ids.blank?
        isoniazid_concept_id = ConceptName.find_by(name: 'Isoniazid').concept_id
        pyridoxine_concept_id = ConceptName.find_by(name: 'Pyridoxine').concept_id

        results = ActiveRecord::Base.connection.select_all(
          "SELECT ods.patient_id FROM orders ods
          INNER JOIN drug_order dos ON ods.order_id = dos.order_id AND ods.voided = 0
          WHERE ods.concept_id IN (#{isoniazid_concept_id}, #{pyridoxine_concept_id})
          AND dos.quantity IS NOT NULL
          AND ods.patient_id in (#{patient_ids.join(',')})
          AND ods.start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND DATE(ods.start_date) = (SELECT MAX(DATE(o.start_date)) FROM orders o
                                      INNER JOIN drug_order d ON o.order_id = d.order_id AND o.voided = 0
                                      WHERE o.concept_id IN (#{isoniazid_concept_id}, #{pyridoxine_concept_id})
                                      AND o.patient_id = ods.patient_id
                                      AND d.quantity IS NOT NULL
                                      AND o.start_date BETWEEN '#{@start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                                      AND '#{@end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY ods.patient_id;"
        )

        results_patients = []

        (results || []).each do |row|
          results_patients << row['patient_id'].to_i
        end

        return results_patients
      end

      def tb_screened(patient_ids)
        return [] if patient_ids.blank?

        results = ActiveRecord::Base.connection.select_all <<EOF
        SELECT e.*, tb_status FROM temp_earliest_start_date e
          INNER JOIN temp_patient_tb_status s ON s.patient_id = e.patient_id
          INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
          WHERE o.cum_outcome = 'On antiretrovirals' AND e.patient_id IN(#{patient_ids.join(',')})
          AND DATE(e.date_enrolled) <= '#{@end_date.to_date}';
EOF

        
        patient_ids = []
        (results || []).each do |r|
          patient_ids << r['patient_id'].to_i unless r['tb_status'].blank?
        end

        return patient_ids
      end 

      def screened_for_tb_female_client(group)
        results = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id FROM temp_disaggregated
        WHERE maternal_status = "#{group}" GROUP BY patient_id;
EOF
                                                    
        patient_ids = []
        (results || []).each do |r|
          patient_ids << r['patient_id'].to_i
        end
        
        return tb_screened(patient_ids)
      end
      
      def female_clients_given_ipt(group)
        results = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id FROM temp_disaggregated
        WHERE maternal_status = "#{group}" GROUP BY patient_id;
EOF
                                                    
        patient_ids = []
        (results || []).each do |r|
          patient_ids << r['patient_id'].to_i
        end
        
        return given_ipt(patient_ids)
      end
      
    end




  end
end
