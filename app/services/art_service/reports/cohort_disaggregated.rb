# frozen_string_literal: true

module ARTService
  module Reports
    class CohortDisaggregated
      def initialize(name:, type:, start_date:, end_date:, rebuild:)
        @name = name
        @type = type
        @start_date = start_date
        @end_date = end_date
        @rebuild = rebuild
      end

      def find_report
        build_report
      end

      def build_report
        builder = CohortDisaggregatedBuilder.new
        builder.build(nil, @start_date, @end_date)
      end

      def initialize_disaggregated

        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_disaggregated')

        ActiveRecord::Base.connection.execute(
          'CREATE TABLE IF NOT EXISTS temp_disaggregated (
             patient_id INTEGER PRIMARY KEY,
             age_group VARCHAR(20),
             initial_maternal_status VARCHAR(10),
             maternal_status VARCHAR(10),
             given_ipt INT(1),
             screened_for_tb INT(1)
          );'
        )

        return {temp_disaggregated: 'created'}
      end

      def disaggregated(quarter, age_group)

        temp_outcome_table = 'temp_patient_outcomes'

        if quarter == 'pepfar'
          start_date = @start_date
          end_date = @end_date
          temp_outcome_table = 'temp_pepfar_patient_outcomes'

          begin
            records = ActiveRecord::Base.connection.select_one('SELECT count(*) rec_count FROM temp_pepfar_patient_outcomes;')
            if records['rec_count'].to_i < 1
              @rebuild = true
            end
          rescue
            initialize_disaggregated
            rebuild_outcomes
          end

          if @rebuild
            initialize_disaggregated
            rebuild_outcomes
          end


        else
          start_date, end_date = generate_start_date_and_end_date(quarter)

          if @rebuild && quarter  == 'Custom'
            initialize_disaggregated
            art_service = ARTService::Reports::CohortBuilder.new()
            art_service.create_tmp_patient_table
            art_service.load_data_into_temp_earliest_start_date(end_date)
            art_service.update_cum_outcome(end_date)
            art_service.update_tb_status(end_date)
          end
        end

        tmp = get_age_groups(age_group, start_date, end_date, temp_outcome_table)


        #A hack to get female that were pregnant / breastfeeding at the beginning of the reporting period + those are currently the same state
        if(age_group == 'Pregnant')
          tmp_arr = []
          (tmp || []).each do |data|
            begin
              date_enrolled  = data['date_enrolled'].to_date
            rescue
              raise data.inspect
            end
            earliest_start_date = data['earliest_start_date'] rescue date_enrolled

            imstaus = data['initial_maternal_status']
            mstatus = data['mstatus']

            if(date_enrolled >= start_date && date_enrolled <= end_date) && imstaus == 'FP' && (date_enrolled == earliest_start_date)
              tmp_arr << data
            elsif mstatus == 'FP'
              tmp_arr << data
            end
          end

          tmp = tmp_arr
        end

        if(age_group == 'Breastfeeding')
          tmp_arr = []
          (tmp || []).each do |data|
            begin
              date_enrolled  = data['date_enrolled'].to_date
            rescue
              raise data.inspect
            end
            earliest_start_date = data['earliest_start_date'] rescue date_enrolled

            imstaus = data['initial_maternal_status']
            mstatus = data['mstatus']

            if(date_enrolled >= start_date && date_enrolled <= end_date) && imstaus == 'FBf' && (date_enrolled == earliest_start_date)
              tmp_arr << data
            elsif mstatus == 'FBf'
              tmp_arr << data
            end
          end

          tmp = tmp_arr
        end
        # ........................... Hack ends .......... Will clean up later




        on_art = []
        all_clients = []
        all_clients_outcomes = {}

        (tmp || []).each do |pat|
          patient_id = pat['patient_id'].to_i
          outcome = pat['outcome']

          on_art << patient_id if outcome == 'On antiretrovirals'
          all_clients << patient_id
          all_clients_outcomes[patient_id] = outcome
        end

        list = {}

        if all_clients.blank? && (age_group == 'Breastfeeding' || age_group == 'Pregnant')
          list[age_group] = {}
          list[age_group]['F'] = {
            tx_new: [], tx_curr: [],
            tx_screened_for_tb: [],
            tx_given_ipt: []
          }
          return list
        elsif all_clients.blank?
          return {}
        end

        if age_group.match(/year|month/i)
          big_insert tmp, age_group
        end

        (tmp || []).each do |r|
          gender = r['gender']&.first || 'Unknown'
          patient_id = r['patient_id'].to_i
          tx_new, tx_curr, tx_given_ipt, tx_screened_for_tb = get_numbers(r, age_group, start_date, end_date, all_clients_outcomes)

          list[age_group] = {} if list[age_group].blank?

          list[age_group][gender] = {
            tx_new: [], tx_curr: [],
            tx_screened_for_tb: [],
            tx_given_ipt: []
          } if list[age_group][gender].blank?


          list[age_group][gender][:tx_new] << r['patient_id'] if tx_new
          list[age_group][gender][:tx_curr] << r['patient_id'] if tx_curr
          list[age_group][gender][:tx_given_ipt] << r['patient_id'] if tx_given_ipt
          list[age_group][gender][:tx_screened_for_tb] << r['patient_id'] if tx_screened_for_tb

          date_enrolled = r['date_enrolled'].to_date

          if gender == 'F' && all_clients_outcomes[patient_id] == 'On antiretrovirals'
            insert_female_maternal_status(patient_id, age_group, end_date)
          elsif gender == 'F' && (date_enrolled >= start_date && date_enrolled <= end_date)
            insert_female_maternal_status(patient_id, age_group, end_date)
          end

        end

        return list
      end

      def generate_start_date_and_end_date(quarter)
        return [@start_date, @end_date] if quarter == 'Custom'
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

      def screened_for_tb(my_patient_id, age_group, start_date, end_date)
        data = ActiveRecord::Base.connection.select_one <<EOF
        SELECT patient_screened_for_tb(#{my_patient_id},
          '#{start_date.to_date}', '#{end_date.to_date}') AS screened;
EOF

        screened = data['screened'].to_i

        ActiveRecord::Base.connection.execute <<EOF
        UPDATE temp_disaggregated SET screened_for_tb =  #{screened},
        age_group = '#{age_group}'
        WHERE patient_id = #{my_patient_id};
EOF

        return screened
      end

      def given_ipt(my_patient_id, age_group, start_date, end_date)

        data = ActiveRecord::Base.connection.select_one <<EOF
        SELECT patient_given_ipt(#{my_patient_id},
          '#{start_date.to_date}', '#{end_date.to_date}') AS given;
EOF

        given = data['given'].to_i

        ActiveRecord::Base.connection.execute <<EOF
        UPDATE temp_disaggregated SET given_ipt =  #{given} ,
        age_group = '#{age_group}'
        WHERE patient_id = #{my_patient_id};
EOF

        return given
      end

      def get_numbers(data, age_group, start_date, end_date, outcomes)
        patient_id = data['patient_id'].to_i
        tx_new = false
        tx_curr = false
        tx_screened_for_tb = false
        tx_given_ipt  = false
        outcome = outcomes[patient_id]

        begin
          date_enrolled  = data['date_enrolled'].to_date
        rescue
          raise data.inspect
        end
        earliest_start_date  = data['earliest_start_date'].to_date rescue nil

        if date_enrolled >= start_date && date_enrolled <= end_date
          if date_enrolled == earliest_start_date
            tx_new = true
          end unless earliest_start_date.blank?

          if outcome == 'On antiretrovirals'
            tx_curr = true
          end
        elsif outcome == 'On antiretrovirals'
          tx_curr = true
        end

        if (age_group == 'Pregnant')
          if data['initial_maternal_status'] != 'FP' && tx_new
            tx_new = false
          end

          if data['mstatus'] != 'FP'
            tx_curr = false
          end
        end

        if (age_group == 'Breastfeeding')
          if data['initial_maternal_status'] != 'FBf' && tx_new
            tx_new = false
          end

          if data['mstatus'] != 'FBf'
            tx_curr = false
          end
        end

        return [tx_new, tx_curr, tx_given_ipt, tx_screened_for_tb]
      end

      def get_age_groups(age_group, start_date, end_date, temp_outcome_table)
        if age_group != 'Pregnant' && age_group != 'FNP' && age_group != 'Not pregnant' && age_group != 'Breastfeeding'

          results = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT
              `cohort_disaggregated_age_group`(date(birthdate), date('#{@end_date}')) AS age_group,
              o.cum_outcome AS outcome, e.*
            FROM earliest_start_date e
            LEFT JOIN `#{temp_outcome_table}` o ON o.patient_id = e.patient_id
            WHERE  date_enrolled IS NOT NULL AND DATE(date_enrolled) <= DATE('#{@end_date}')
            AND e.patient_id NOT IN(
            SELECT person_id FROM obs
            WHERE concept_id IN (
              SELECT concept_id FROM concept_name WHERE name LIKE 'Type of patient'
            ) AND value_coded IN (
              SELECT concept_id FROM concept_name WHERE name LIKE 'External Consultation'
            ) AND voided = 0 AND (obs_datetime < DATE('#{@end_date}') + INTERVAL 1 DAY)
            GROUP BY person_id) GROUP BY e.patient_id
            HAVING age_group = '#{age_group}';
          SQL

        elsif age_group == 'Pregnant'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT
              e.*, maternal_status AS mstatus,
              t2.initial_maternal_status,
              t3.cum_outcome AS outcome
            FROM temp_earliest_start_date e
            INNER JOIN temp_disaggregated t2 ON t2.patient_id = e.patient_id
            INNER JOIN `#{temp_outcome_table}` t3 ON t3.patient_id = e.patient_id
            WHERE maternal_status = 'FP' OR initial_maternal_status = 'FP'
            GROUP BY e.patient_id;
EOF

        elsif age_group == 'Breastfeeding'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT
              e.*, maternal_status AS mstatus,
              initial_maternal_status,
              t3.cum_outcome AS outcome
            FROM temp_earliest_start_date e
            INNER JOIN temp_disaggregated t2 ON t2.patient_id = e.patient_id
            INNER JOIN `#{temp_outcome_table}` t3 ON t3.patient_id = e.patient_id
            WHERE maternal_status = 'FBf' OR initial_maternal_status = 'FBf'
            GROUP BY e.patient_id;
EOF

        elsif age_group == 'FNP'
          create_mysql_female_maternal_status
          results = ActiveRecord::Base.connection.select_all <<EOF
            SELECT
              e.*, maternal_status AS mstatus,
              initial_maternal_status,
              t3.cum_outcome AS outcome
            FROM temp_earliest_start_date e
            INNER JOIN temp_disaggregated t2 ON t2.patient_id = e.patient_id
            INNER JOIN `#{temp_outcome_table}` t3 ON t3.patient_id = e.patient_id
            WHERE maternal_status = 'FNP'
            GROUP BY e.patient_id;
EOF

        end

        return results

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


SET @reason_for_starting = (SELECT concept_id FROM concept_name WHERE name = 'Reason for ART eligibility' LIMIT 1);

SET @pregnant_concepts := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name IN('Is patient pregnant?','Patient pregnant'));
SET @breastfeeding_concept := (SELECT GROUP_CONCAT(concept_id) FROM concept_name WHERE name = 'Breastfeeding');

SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@pregnant_concepts) AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime);
SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime);

IF pregnant_date IS NULL THEN
  SET pregnant_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime AND value_coded IN(1755));
END IF;

IF breastfeeding_date IS NULL THEN
  SET breastfeeding_date = (SELECT MAX(obs_datetime) FROM obs WHERE concept_id = @reason_for_starting AND voided = 0 AND person_id = my_patient_id AND obs_datetime <= end_datetime AND value_coded IN(834,5632));
END IF;

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

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = pregnant_date);
    IF obs_value_coded IN(1755) THEN SET maternal_status = 'FP';
    END IF;
  END IF;

  IF maternal_status = 'Check FP' THEN SET maternal_status = 'FNP';
  END IF;
END IF;

IF maternal_status = 'Check BF' THEN

  SET obs_value_coded = (SELECT value_coded FROM obs WHERE concept_id IN(@breastfeeding_concept) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date LIMIT 1);
  IF obs_value_coded = 1065 THEN SET maternal_status = 'FBf';
  ELSEIF obs_value_coded = 1066 THEN SET maternal_status = 'FNP';
  END IF;

  IF obs_value_coded IS NULL THEN
    SET obs_value_coded = (SELECT GROUP_CONCAT(value_coded) FROM obs WHERE concept_id IN(7563) AND voided = 0 AND person_id = my_patient_id AND obs_datetime = breastfeeding_date);
    IF obs_value_coded IN(834,5632) THEN SET maternal_status = 'FBf';
    END IF;
  END IF;

  IF maternal_status = 'Check BF' THEN SET maternal_status = 'FNP';
  END IF;
END IF;



RETURN maternal_status;
END;
EOF

      end

      def rebuild_outcomes
        ActiveRecord::Base.connection.execute(
          'DROP TABLE IF EXISTS `temp_pepfar_patient_outcomes`'
        )

        ActiveRecord::Base.connection.execute(
          "CREATE TABLE temp_pepfar_patient_outcomes AS (
            SELECT e.patient_id, pepfar_patient_outcome(e.patient_id, DATE('#{@end_date.to_date}')) AS cum_outcome
            FROM temp_earliest_start_date e WHERE DATE(e.date_enrolled) <= DATE('#{@end_date.to_date}')
            GROUP BY e.patient_id
          )"
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_pepfar_patient_outcomes
           ADD INDEX patient_id_index (patient_id)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_pepfar_patient_outcomes
           ADD INDEX cum_outcome_index (cum_outcome)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_pepfar_patient_outcomes
           ADD INDEX patient_id_cum_outcome_index (patient_id, cum_outcome)'
        )

      end

      def insert_female_maternal_status(patient_id, age_group, end_date)
        encounter_types = []
        encounter_types << EncounterType.find_by_name('HIV CLINIC CONSULTATION').encounter_type_id
        encounter_types << EncounterType.find_by_name('HIV STAGING').encounter_type_id

        pregnant_concepts = []
        pregnant_concepts << ConceptName.find_by_name('Is patient pregnant?').concept_id
        pregnant_concepts << ConceptName.find_by_name('patient pregnant').concept_id

        results = ActiveRecord::Base.connection.select_all(
          "SELECT person_id, obs.value_coded value_coded FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0 AND enc.program_id = 1
          WHERE obs.person_id = #{patient_id}
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND obs.concept_id IN(#{pregnant_concepts.join(',')})
          AND obs.voided = 0 AND enc.encounter_type IN(#{encounter_types.join(',')})
          AND DATE(obs.obs_datetime) = (SELECT MAX(DATE(o.obs_datetime)) FROM obs o
                        INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                        AND e.program_id = 1 AND e.voided = 0
                        WHERE o.concept_id IN(#{pregnant_concepts.join(',')})
                        AND o.voided = 0 AND o.person_id = obs.person_id
                        AND o.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY obs.person_id HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;"
        )

       female_maternal_status = results.blank? ? 'FNP' : 'FP'

       if female_maternal_status == 'FNP'

        breastfeeding_concepts = []
        breastfeeding_concepts <<  ConceptName.find_by_name('Breast feeding?').concept_id
        breastfeeding_concepts <<  ConceptName.find_by_name('Breast feeding').concept_id
        breastfeeding_concepts <<  ConceptName.find_by_name('Breastfeeding').concept_id

        results2 = ActiveRecord::Base.connection.select_all(
          "SELECT person_id, obs.value_coded value_coded  FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0 AND enc.program_id = 1
          WHERE obs.person_id =#{patient_id}
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND obs.concept_id IN(#{breastfeeding_concepts.join(',')})
          AND obs.voided = 0 AND enc.encounter_type IN(#{encounter_types.join(',')})
          AND DATE(obs.obs_datetime) = (SELECT MAX(DATE(o.obs_datetime)) FROM obs o
                        INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                        AND e.program_id = 1 AND e.voided = 0
                        WHERE o.concept_id IN(#{breastfeeding_concepts.join(',')}) AND o.voided = 0
                        AND o.person_id = obs.person_id
                        AND o.obs_datetime <='#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY obs.person_id HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;"
        )

         female_maternal_status = results2.blank? ? 'FNP' : 'FBf'
       end

       results = ActiveRecord::Base.connection.select_all(
          "SELECT person_id, obs.value_coded value_coded FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0 AND enc.program_id = 1
          WHERE obs.person_id = #{patient_id}
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND obs.concept_id IN(#{pregnant_concepts.join(',')})
          AND obs.voided = 0 AND enc.encounter_type IN(#{encounter_types.join(',')})
          AND DATE(obs.obs_datetime) = (SELECT DATE(es.earliest_start_date) FROM temp_earliest_start_date es
                                        WHERE es.patient_id = obs.person_id)
          GROUP BY obs.person_id HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;"
        )

       initial_female_maternal_status = results.blank? ? 'FNP' : 'FP'

       if initial_female_maternal_status == 'FNP'

        breastfeeding_concepts = []
        breastfeeding_concepts <<  ConceptName.find_by_name('Breast feeding?').concept_id
        breastfeeding_concepts <<  ConceptName.find_by_name('Breast feeding').concept_id
        breastfeeding_concepts <<  ConceptName.find_by_name('Breastfeeding').concept_id

        results2 = ActiveRecord::Base.connection.select_all(
          "SELECT person_id, obs.value_coded value_coded  FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0 AND enc.program_id = 1
          WHERE obs.person_id =#{patient_id}
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND obs.concept_id IN(#{breastfeeding_concepts.join(',')})
          AND obs.voided = 0 AND enc.encounter_type IN(#{encounter_types.join(',')})
          AND DATE(obs.obs_datetime) = (SELECT DATE(es.earliest_start_date) FROM temp_earliest_start_date es
                                        WHERE es.patient_id = obs.person_id)
          GROUP BY obs.person_id HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;"
        )

        initial_female_maternal_status = results2.blank? ? 'FNP' : 'FBf'
       end


       ActiveRecord::Base.connection.execute <<EOF
        UPDATE temp_disaggregated SET maternal_status =  '#{female_maternal_status}',
          initial_maternal_status = '#{initial_female_maternal_status}',
           age_group = '#{age_group}' WHERE patient_id = #{patient_id};
EOF


      end

      def big_insert(data, age_group)

        (data || []).each do |r|
          ActiveRecord::Base.connection.execute <<EOF
            INSERT INTO temp_disaggregated (patient_id, age_group)
            VALUES(#{r['patient_id']}, '#{age_group}');
EOF

        end

      end

    end
  end

end
