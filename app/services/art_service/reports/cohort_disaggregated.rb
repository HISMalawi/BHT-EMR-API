# frozen_string_literal: true

module ARTService
  module Reports
    class CohortDisaggregated
      def initialize(name:, type:, start_date:, end_date:)
        @name = name
        @type = type
        @start_date = start_date
        @end_date = end_date
      end

      def find_report
        build_report
      end

      def build_report
        builder = CohortDisaggregatedBuilder.new
        builder.build(nil, @start_date, @end_date)
      end

      def disaggregated(quarter, age_group)
        create_mysql_age_group_function
        start_date, end_date = generate_start_date_and_end_date(quarter)
        tmp = get_age_groups(age_group, start_date, end_date)

        on_art = []

        (tmp || []).each do |pat|
          on_art << pat['patient_id'].to_i
        end

        list = {}
        
        if on_art.blank? && (age_group == 'Breastfeeding' || age_group == 'Pregnant')
          list[age_group] = {}
          list[age_group]['F'] = {
            tx_new: 0, tx_curr: 0,
            tx_screened_for_tb: 0,
            tx_given_ipt: 0
          }
          return list
        elsif on_art.blank?
           return {}
        end

        tb_screened = screened_for_tb(start_date, end_date, on_art)
        ipt_given = given_ipt(start_date, end_date, on_art)
        

        (tmp || []).each do |r|
          if list[age_group].blank?
            list[age_group] = {}
          end

          if list[age_group][r['gender']].blank?
            list[age_group][r['gender']] = {
              tx_new: 0, tx_curr: 0,
              tx_screened_for_tb: 0,
              tx_given_ipt: 0
            }
          end

          tx_new, tx_curr, tx_screened_for_tb, tx_given_ipt = get_numbers(r['patient_id'].to_i,
            tb_screened, ipt_given, r['earliest_start_date'], r['date_enrolled'],
            start_date, end_date)

          

          list[age_group][r['gender']][:tx_new] += tx_new
          list[age_group][r['gender']][:tx_curr] += tx_curr
          list[age_group][r['gender']][:tx_screened_for_tb] += tx_screened_for_tb
          list[age_group][r['gender']][:tx_given_ipt] += tx_given_ipt
        
        end

        return list
      end

      def generate_start_date_and_end_date(quarter)
        quarter, quarter_year = quarter.humanize.split(" ")

        quarter_start_dates = [
          "#{quarter_year}-01-01".to_date,
          "#{quarter_year}-04-01".to_date,
          "#{quarter_year}-07-01".to_date,
          "#{quarter_year}-10-01".to_date
        ]

        quarter_end_dates = [
          "#{quarter_year}-03-31".to_date,
          "#{quarter_year}-06-30".to_date,
          "#{quarter_year}-09-30".to_date,
          "#{quarter_year}-12-31".to_date
        ]

        current_quarter   = (quarter.match(/\d+/).to_s.to_i - 1)
        quarter_beginning = quarter_start_dates[current_quarter]
        quarter_ending    = quarter_end_dates[current_quarter]

        date_range = [quarter_beginning, quarter_ending]
      end

      def screened_for_tb(start_date, end_date, on_art_patient_ids)
        tb_treatment = ConceptName.find_by_name('TB treatment').concept_id
        tb_status_id = ConceptName.find_by_name('TB status').concept_id
        clinical_consultation = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id

        data = ActiveRecord::Base.connection.select_all <<EOF
          SELECT person_id, MAX(obs.obs_datetime) FROM obs 
          INNER JOIN temp_earliest_start_date e 
          ON e.patient_id = obs.person_id
          WHERE obs.concept_id IN(#{tb_treatment},#{tb_status_id}) AND obs.voided = 0
          AND obs.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND e.date_enrolled BETWEEN
          '#{start_date.to_date}' AND '#{end_date.to_date}'
          AND obs.person_id IN(#{on_art_patient_ids.join(',')})
          GROUP BY obs.person_id;
EOF

        tb_screened = []
        (data || []).each do |r| 
          tb_screened << r['person_id'].to_i
        end

        return tb_screened
      end

      def given_ipt(start_date, end_date, on_art_patient_ids)
        
        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT est.patient_id FROM temp_earliest_start_date est
        WHERE date_enrolled <= '#{end_date.to_date}'
        AND est.patient_id IN(#{on_art_patient_ids.join(',')});
EOF

        return [] if data.blank?

        patient_ids = []

        (data || []).each do |d|
          patient_ids << d['patient_id'].to_i
        end

        patient_ids = patient_ids.blank? ? [0] : patient_ids

        ipt_drug_ids = Drug.where(concept_id: (ConceptName.find_by_name('Isoniazid').concept_id)).map(&:drug_id)

        data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT o.patient_id FROM orders o
        INNER JOIN drug_order d
        WHERE d.drug_inventory_id IN(#{ipt_drug_ids.join(',')}) 
        AND d.quantity >= 0 AND o.voided = 0
        AND o.patient_id IN(#{on_art_patient_ids.join(',')})
        AND o.start_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
        AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
        GROUP BY o.patient_id;
EOF

        patient_ids = []

        (data || []).each do |d|
          patient_ids << d['patient_id'].to_i
        end
        
        return patient_ids
      end

      def create_mysql_age_group_function
        ActiveRecord::Base.connection.execute <<EOF
        DROP FUNCTION IF EXISTS cohort_disaggregated_age_group;
EOF

        ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION cohort_disaggregated_age_group(birthdate date, end_date date) RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
DECLARE age_in_months INT(11);
DECLARE age_in_years INT(11);
DECLARE age_group VARCHAR(15);

SET age_in_months = (SELECT timestampdiff(month, birthdate, end_date));
SET age_in_years  = (SELECT timestampdiff(year, birthdate, end_date));
SET age_group = ('Unknown');          

IF age_in_months >= 1 AND age_in_months <= 5 THEN SET age_group = "0-5 months";
ELSEIF age_in_months > 5 AND age_in_months <= 11 THEN SET age_group = "6-11 months";
ELSEIF age_in_months > 11 AND age_in_months <= 23 THEN SET age_group = "12-23 months";
ELSEIF age_in_years >= 2 AND age_in_years <= 4 THEN SET age_group = "2-4 years";
ELSEIF age_in_years >= 5 AND age_in_years <= 9 THEN SET age_group = "5-9 years";
ELSEIF age_in_years >= 10 AND age_in_years <= 14 THEN SET age_group = "10-14 years";
ELSEIF age_in_years >= 15 AND age_in_years <= 17 THEN SET age_group = "15-17 years";
ELSEIF age_in_years >= 18 AND age_in_years <= 19 THEN SET age_group = "18-19 years";
ELSEIF age_in_years >= 20 AND age_in_years <= 24 THEN SET age_group = "20-24 years";
ELSEIF age_in_years >= 25 AND age_in_years <= 29 THEN SET age_group = "25-29 years";
ELSEIF age_in_years >= 30 AND age_in_years <= 34 THEN SET age_group = "30-34 years";
ELSEIF age_in_years >= 35 AND age_in_years <= 39 THEN SET age_group = "35-39 years";
ELSEIF age_in_years >= 40 AND age_in_years <= 44 THEN SET age_group = "40-44 years";
ELSEIF age_in_years >= 45 AND age_in_years <= 49 THEN SET age_group = "45-49 years";
ELSEIF age_in_years >= 50 THEN SET age_group = "50 plus years";
END IF;

RETURN age_group;
END;
EOF

      end

      def get_numbers(patient_id, tbs, ipt, esd, de, start_date, end_date)
        tx_new = 0
        tx_curr = 0
        tx_screened_for_tb = 0
        tx_given_ipt  = 0

        begin
          esd = esd.to_date
          de  = de.to_date
          if de != esd 
            tx_curr = 1
          elsif de == esd && (de >= start_date.to_date && de <= end_date.to_date) 
            tx_new = 1
          else
            tx_curr = 1
          end
        rescue
          tx_curr = 1
        end

        tx_screened_for_tb = (tbs.include?(patient_id) == true ? 1 : 0)
        tx_given_ipt = (ipt.include?(patient_id) == true ? 1 : 0)

        return [tx_new, tx_curr, tx_screened_for_tb, tx_given_ipt]
      end

      def get_age_groups(age_group, start_date, end_date)
        if age_group != 'Pregnant' && age_group != 'FNP' && age_group != 'Not pregnant' && age_group != 'Breastfeeding'
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT 
            e.*,  cohort_disaggregated_age_group(DATE(e.birthdate), DATE('#{end_date}')) AS age_group
            FROM temp_earliest_start_date e 
            INNER JOIN temp_patient_outcomes t2 ON t2.patient_id = e.patient_id
            WHERE cum_outcome = 'On antiretrovirals'
            GROUP BY e.patient_id HAVING age_group = '#{age_group}';
EOF

        elsif age_group == 'Pregnant'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT 
            e.*, female_maternal_status(e.patient_id, TIMESTAMP('#{end_date.strftime('%Y-%m-%d 23:59:59')}')) AS mstatus
            FROM temp_earliest_start_date e 
            INNER JOIN temp_patient_outcomes t2 ON t2.patient_id = e.patient_id
            WHERE cum_outcome = 'On antiretrovirals' AND gender = 'F'
            GROUP BY e.patient_id HAVING mstatus = 'FP';
EOF

        elsif age_group == 'Breastfeeding'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT 
            e.*, female_maternal_status(e.patient_id, TIMESTAMP('#{end_date.strftime('%Y-%m-%d 23:59:59')}')) AS mstatus
            FROM temp_earliest_start_date e 
            INNER JOIN temp_patient_outcomes t2 ON t2.patient_id = e.patient_id
            WHERE cum_outcome = 'On antiretrovirals' AND gender = 'F'
            GROUP BY e.patient_id HAVING mstatus = 'FBf';
EOF

        elsif age_group == 'FNP'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT 
            e.*, female_maternal_status(e.patient_id, TIMESTAMP('#{end_date.strftime('%Y-%m-%d 23:59:59')}')) AS mstatus
            FROM temp_earliest_start_date e 
            INNER JOIN temp_patient_outcomes t2 ON t2.patient_id = e.patient_id
            WHERE cum_outcome = 'On antiretrovirals' AND gender = 'F'
            GROUP BY e.patient_id HAVING mstatus = 'FNP';
EOF

        end

        return results
        
      end

      def all_women(end_date)
      end

      def pregnant_women(end_date)
      end
      
      def breastfeeding_women(end_date)
      end

      def create_mysql_female_maternal_status
        ActiveRecord::Base.connection.execute <<EOF
        DROP FUNCTION IF EXISTS female_maternal_status;
EOF

        ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION female_maternal_status(my_patient_id int, end_datetime datetime) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN

DECLARE breastfeeding_date DATETIME;
DECLARE pregnant_date DATETIME;
DECLARE maternal_status VARCHAR(20);
DECLARE obs_value_coded INT(11);

SET @pregnant_concepts := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name IN('Is patient pregnant?','Patient pregnant'));
SET @breastfeeding_concept := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name = 'Breastfeeding');

SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime);
SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime);

IF pregnant_date IS NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "FNP";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Unknown";
ELSEIF pregnant_date IS NULL AND breastfeeding_date IS NOT NULL THEN SET maternal_status = "Check BF";
ELSEIF pregnant_date IS NOT NULL AND breastfeeding_date IS NULL THEN SET maternal_status = "Check FP";
END IF;

IF maternal_status = 'Unknown' THEN
  
  IF breastfeeding_date <= pregnant_date THEN  
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = pregnant_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';  
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;  
  END IF;
  
  IF breastfeeding_date > pregnant_date THEN  
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';  
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;  
  END IF;
  
  IF DATE(breastfeeding_date) = DATE(pregnant_date) AND maternal_status = 'FNP' THEN  
    SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date LIMIT 1);
    IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
    ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
    END IF;  
  END IF;  
END IF;

IF maternal_status = 'Check FP' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = pregnant_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FP';  
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;  

  IF maternal_status = 'Check FP' THEN SET maternal_status = 'FNP';
  END IF;
END IF;

IF maternal_status = 'Check BF' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';  
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;  

  IF maternal_status = 'Check BF' THEN SET maternal_status = 'FNP';
  END IF;
END IF;



RETURN maternal_status;
END;
EOF

      end





    end
  end

end
