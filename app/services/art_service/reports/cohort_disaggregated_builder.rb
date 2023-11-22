# frozen_string_literal: true

module ArtService
  module Reports
    class CohortDisaggregatedBuilder < CohortBuilder
      def build(_cohort_struct, start_date, end_date)
        build_disaggregated_report(cohort(nil, start_date, end_date), start_date, end_date)
      end

      def cohort(_cohort_struct, start_date, end_date)
        time_started = Time.now.strftime('%Y-%m-%d %H:%M:%S')

        @cohort_struct = cohort_struct = CohortStruct.new

        #=end
        # Get earliest date enrolled
        @cohort_cum_start_date = cum_start_date = get_cum_start_date

        # Total registered
        cohort_struct.total_registered = total_registered(start_date, end_date)
        cohort_struct.cum_total_registered = total_registered(cum_start_date, end_date)

        # Patients initiated on ART first time
        cohort_struct.initiated_on_art_first_time = initiated_on_art_first_time(start_date, end_date)
        cohort_struct.cum_initiated_on_art_first_time = initiated_on_art_first_time(cum_start_date, end_date)

        # Patients re-initiated on ART
        cohort_struct.re_initiated_on_art = re_initiated_on_art(start_date, end_date)
        cohort_struct.cum_re_initiated_on_art = re_initiated_on_art(cum_start_date, end_date)

        # Patients transferred in on ART
        cohort_struct.transfer_in = transfer_in(start_date, end_date)
        cohort_struct.cum_transfer_in = transfer_in(cum_start_date, end_date)

        # All males
        cohort_struct.all_males = males(start_date, end_date)
        cohort_struct.cum_all_males = males(cum_start_date, end_date)

        # Unknown age
        cohort_struct.unknown_age = unknown_age(start_date, end_date)
        cohort_struct.cum_unknown_age = unknown_age(cum_start_date, end_date)

        #     No TB
        #     total_registered - (current_episode - tb_within_the_last_two_years)
        cohort_struct.no_tb = no_tb(cohort_struct.total_registered, cohort_struct.tb_within_the_last_two_years, cohort_struct.current_episode_of_tb)
        cohort_struct.cum_no_tb = cum_no_tb(cohort_struct.cum_total_registered, cohort_struct.cum_tb_within_the_last_two_years, cohort_struct.cum_current_episode_of_tb)

        #  Total Alive and On ART
        #  Unique PatientProgram entries at the current location for those patients with at least one state
        #  ON ARVs and earliest start date of the 'ON ARVs' state less than or equal to end date of quarter
        #  and latest state is ON ARVs  (Excluding defaulters)
        cohort_struct.total_alive_and_on_art = get_outcome('On antiretrovirals')

        # Pregnant women
        #
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as PATIENT PREGNANT
        cohort_struct.total_pregnant_women = total_pregnant_women(cohort_struct.total_alive_and_on_art, cum_start_date, end_date)

        #  Breastfeeding mothers
        #
        #  Unique PatientProgram entries at the current location for those patients with at least one state
        #  ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
        #  and having a REASON FOR ELIGIBILITY observation with an answer as BREASTFEEDING
        cohort_struct.total_breastfeeding_women = total_breastfeeding_women(cohort_struct.total_alive_and_on_art, cum_start_date, end_date)

        # Non-pregnant females (all ages)

        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having gender of
        # related PERSON entry as F for female and no entries of 'IS PATIENT PREGNANT?' observation answered 'YES'
        # in related HIV CLINIC CONSULTATION encounters not within 28 days from earliest registration date
        pregnant_females = []
        (cohort_struct.total_pregnant_women || []).each do |patient|
          pregnant_females << patient['person_id'].to_i
        end
        cohort_struct.non_pregnant_females = non_pregnant_females(start_date, end_date, pregnant_females)
        cohort_struct.cum_non_pregnant_females = non_pregnant_females(cum_start_date, end_date, pregnant_females)

        puts "Started at: #{time_started}. Finished at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
        cohort_struct
      end

      def build_disaggregated_report(cohort, start_date, end_date)
        @age_groups = ['0-5 months', '6-11 months', '12-23 months', '2-4 years',
                       '5-9 years', '10-14 years', '15-17 years', '18-19 years',
                       '20-24 years', '25-29 years', '30-34 years', '35-39 years',
                       '40-44 years', '45-49 years', '50+ years', 'All']

        report = {}
        counter = 1

        %w[Male Female].each do |gender|
          @age_groups.each do |ag|
            next if ag =~ /all/i

            report[counter] = {} if report[counter].blank?
            report[counter][gender] = {} if report[counter][gender].blank?
            report[counter][gender][ag] = get_data(cohort, start_date, end_date, gender, ag)
            counter += 1
          end
        end

        %w[M FP FNP FBf].each do |gender|
          @age_groups.each do |ag|
            next unless ag =~ /all/i

            report[counter] = {} if report[counter].blank?
            report[counter][gender] = {} if report[counter][gender].blank?
            report[counter][gender][ag] = get_data(cohort, start_date, end_date, gender, ag)
            counter += 1
          end
        end

        report
      end

      def get_data(cohort, start_date, end_date, gender, age_group)
        @cohort = cohort

        if gender == 'Male' || gender == 'Female'
          if age_group == '50+ years'
            yrs_months = 'year'; age_to = 1000; age_from = 50
          elsif /years/i.match?(age_group)
            age_from, age_to = age_group.sub(' years', '').split('-')
            yrs_months = 'year'
          elsif /months/i.match?(age_group)
            age_from, age_to = age_group.sub(' months', '').split('-')
            yrs_months = 'month'
          end

          g = gender.first

          started_on_art = get_started_on_art(yrs_months, age_from, age_to, g, start_date, end_date)
          alive_on_art = get_alive_on_art(yrs_months, age_from, age_to, g, @cohort_cum_start_date, end_date)
          started_on_ipt = get_started_on_ipt(yrs_months, age_from, age_to, g, @cohort_cum_start_date, end_date)
          screened_for_tb = get_screened_for_tb(yrs_months, age_from, age_to, g, @cohort_cum_start_date, end_date)

          return [started_on_art&.length || 0,
                  alive_on_art&.length || 0,
                  started_on_ipt&.length || 0,
                  screened_for_tb&.length || 0]
        end

        if gender == 'M'
          age_from = 0; age_to = 1000; yrs_months = 'year'
          started_on_art = get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)
          alive_on_art = get_alive_on_art(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date)
          started_on_ipt = get_started_on_ipt(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date)
          screened_for_tb = get_screened_for_tb(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date)

          return [started_on_art&.length || 0,
                  alive_on_art&.length || 0,
                  started_on_ipt&.length || 0,
                  screened_for_tb&.length || 0]
        end

        if gender == 'FP'
          a, b, c, d = get_fp(start_date, end_date)
          return [a.length, b.length, c.length, d.length]
        end

        if gender == 'FNP'
          fnp_a, fnp_b, fnp_c, fnp_d = get_fnp(start_date, end_date)
          return [fnp_a.length, fnp_b.length, fnp_c.length, fnp_d.length]
        end

        if gender == 'FBf'
          a, b, c, d = get_fbf(start_date, end_date)
          return [a.length, b.length, c.length, d.length]
        end

        [0, 0, 0, 0]
      end

      def get_fnp(start_date, end_date)
        age_from = 0; age_to = 1000; yrs_months = 'year'; gender = 'F'

        females_pregnant = []; cum_females_pregnant = []
        breast_feeding_women = []; cum_breast_feeding_women = []

        started_on_art = []; alive_on_art = []
        started_on_ipt = []; screened_for_tb = []

        ###############################################################
        (@cohort.total_breastfeeding_women || []).each do |p|
          date_enrolled_str = ActiveRecord::Base.connection.select_one(
            "SELECT date_enrolled FROM temp_earliest_start_date e
             WHERE patient_id = #{p['person_id']}"
          )

          date_enrolled = date_enrolled_str['date_enrolled'].to_date
          if (date_enrolled >= start_date.to_date) && (end_date.to_date <= end_date.to_date)
            breast_feeding_women << p['person_id'].to_i
            breast_feeding_women = breast_feeding_women.uniq
          else
            cum_breast_feeding_women << p['person_id'].to_i
            cum_breast_feeding_women = cum_breast_feeding_women.uniq
          end
        end

        cum_pregnant_women = @cohort.total_pregnant_women
        (cum_pregnant_women || []).each do |p|
          next if breast_feeding_women.include?(p['person_id'].to_i)

          date_enrolled_str = ActiveRecord::Base.connection.select_one(
            "SELECT date_enrolled FROM temp_earliest_start_date e
             WHERE patient_id = #{p['person_id'].to_i}"
          )

          date_enrolled = date_enrolled_str['date_enrolled'].to_date
          if (date_enrolled >= start_date.to_date) && (end_date.to_date <= end_date.to_date)
            females_pregnant << p['person_id'].to_i
            females_pregnant = females_pregnant.uniq
          else
            cum_females_pregnant << p['person_id'].to_i
            cum_females_pregnant = cum_females_pregnant.uniq
          end
        end

        cum_females_pregnant = (cum_females_pregnant + females_pregnant)&.uniq || []
        cum_breast_feeding_women = cum_breast_feeding_women + breast_feeding_women
        #####################################################################

        (get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |fnp|
          next if females_pregnant.include?(fnp['patient_id'].to_i)
          next if breast_feeding_women.include?(fnp['patient_id'].to_i)

          started_on_art << { patient_id: fnp['patient_id'].to_i, date_enrolled: fnp['date_enrolled'].to_date }
        end

        (get_alive_on_art(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fnp|
          next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
          next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)

          alive_on_art << { patient_id: fnp['patient_id'].to_i }
        end

        (get_started_on_ipt(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fnp|
          next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
          next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)

          started_on_ipt << { patient_id: fnp['patient_id'].to_i }
        end

        (get_screened_for_tb(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fnp|
          next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
          next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)

          screened_for_tb << { patient_id: fnp['patient_id'].to_i }
        end

        [started_on_art, alive_on_art, started_on_ipt, screened_for_tb]
      end

      def get_screened_for_tb(yrs_months, age_from, age_to, gender, start_date, end_date)
        alive_on_art_patient_ids = []
        start_date = @cohort_cum_start_date

        (@cohort.total_alive_and_on_art || []).each do |data|
          alive_on_art_patient_ids << data['patient_id'].to_i
        end

        return [] if alive_on_art_patient_ids.blank?

        tb_treatment = ConceptName.find_by_name('TB treatment').concept_id
        tb_status_id = ConceptName.find_by_name('TB status').concept_id
        clinical_consultation = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id

        ActiveRecord::Base.connection.select_all(
          "SELECT t1.patient_id FROM obs t3
          INNER JOIN temp_earliest_start_date t1 ON t1.patient_id = t3.person_id
          WHERE t3.concept_id IN(#{tb_treatment},#{tb_status_id}) AND t3.voided = 0
          AND t3.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND gender = '#{gender.first}' AND t1.date_enrolled BETWEEN
          '#{start_date.to_date}' AND '#{end_date.to_date}'
          AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
          BETWEEN #{age_from} AND #{age_to} AND t1.patient_id IN(#{alive_on_art_patient_ids.join(',')})
          AND t3.obs_datetime = (
            SELECT MAX(obs_datetime) FROM obs t4
            INNER JOIN encounter e ON e.encounter_id = t4.encounter_id
            AND e.encounter_type = #{clinical_consultation}
            WHERE t3.person_id = t4.person_id
            AND t4.voided = 0 AND t4.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          ) GROUP BY t3.person_id"
        )
      end

      def get_started_on_ipt(yrs_months, age_from, age_to, gender, _start_date, end_date)
        data = ActiveRecord::Base.connection.select_all(
        "SELECT patient_id FROM temp_earliest_start_date
         WHERE gender = '#{gender}' AND earliest_start_date <= '#{end_date.to_date}'
         AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
         BETWEEN #{age_from} AND #{age_to}"
        )

        return [] if data.blank?

        patient_ids = []

        data.each do |d|
          patient_ids << d['patient_id'].to_i
        end

        amount_dispensed = ConceptName.find_by_name('Amount dispensed').concept_id
        ipt_drug_ids = Drug.where(concept_id: ConceptName.find_by_name('Isoniazid').concept_id).map(&:drug_id)

        ActiveRecord::Base.connection.select_all(
          "SELECT obs.person_id patient_id FROM obs
          WHERE concept_id = #{amount_dispensed} AND obs.voided = 0
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND value_drug IN(#{ipt_drug_ids.join(',')}) AND obs.person_id IN(#{patient_ids.join(',')})"
        )
      end

      def get_alive_on_art(yrs_months, age_from, age_to, gender, _start_date, end_date)
        alive_on_art_patient_ids = []

        (@cohort.total_alive_and_on_art || []).each do |data|
          alive_on_art_patient_ids << data['patient_id'].to_i
        end

        return [] if alive_on_art_patient_ids.blank?

        ActiveRecord::Base.connection.select_all(
          "SELECT patient_id FROM temp_earliest_start_date
          WHERE gender = '#{gender}' AND date_enrolled <= '#{end_date.to_date}' AND
          patient_id IN(#{alive_on_art_patient_ids.join(',')})
          AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
          BETWEEN #{age_from} AND #{age_to}"
        )
      end

      def get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, date_enrolled FROM temp_earliest_start_date
          WHERE gender = '#{gender}' AND date_enrolled BETWEEN
          '#{start_date.to_date}' AND '#{end_date.to_date}' AND
          (DATE(date_enrolled) = DATE(earliest_start_date))
          AND timestampdiff(#{yrs_months}, birthdate, DATE(earliest_start_date))
          BETWEEN #{age_from} AND #{age_to}"
        )
      end

      def get_fp(start_date, end_date)
        age_from = 0; age_to = 1000; yrs_months = 'year'; gender = 'F'
        cum_pregnant_women = @cohort.total_pregnant_women

        return [[], [], [], []] if cum_pregnant_women.blank?

        pregnant_women_patient_ids = []

        cum_pregnant_women.each do |p|
          date_enrolled_str = ActiveRecord::Base.connection.select_one(
            "SELECT date_enrolled FROM temp_earliest_start_date e
             WHERE patient_id = #{p['person_id'].to_i}"
          )

          date_enrolled = date_enrolled_str['date_enrolled'].to_date
          if (date_enrolled >= @cohort_cum_start_date.to_date) && (end_date.to_date <= end_date.to_date)
            pregnant_women_patient_ids << p['person_id'].to_i
          end
        end

        started_on_art = []; alive_on_art = []
        started_on_ipt = []; screened_for_tb = []

        (get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |p|
          next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)

          started_on_art << p
        end

        (get_alive_on_art(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |p|
          next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)

          alive_on_art << { patient_id: p['patient_id'].to_i }
        end

        (get_started_on_ipt(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |p|
          next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)

          started_on_ipt << { patient_id: p['patient_id'].to_i }
        end

        (get_screened_for_tb(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |p|
          next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)

          screened_for_tb << { patient_id: p['patient_id'].to_i }
        end

        [started_on_art, alive_on_art,
         started_on_ipt, screened_for_tb]
      end

      def get_fbf(start_date, end_date)
        age_from = 0; age_to = 1000; yrs_months = 'year'; gender = 'F'
        cum_breastfeeding_mothers = @cohort.total_breastfeeding_women

        return [[], [], [], []] if cum_breastfeeding_mothers.blank?

        fbf_women_patient_ids = []

        started_on_art = []; alive_on_art = []
        started_on_ipt = []; screened_for_tb = []

        #########################################################################
        cum_pregnant_women = @cohort.total_pregnant_women
        pregnant_women_patient_ids = []

        cum_pregnant_women.each do |p|
          date_enrolled_str = ActiveRecord::Base.connection.select_one(
            "SELECT date_enrolled FROM temp_earliest_start_date e
             WHERE patient_id = #{p['person_id'].to_i}"
          )

          date_enrolled = date_enrolled_str['date_enrolled'].to_date
          if (date_enrolled >= @cohort_cum_start_date.to_date) && (end_date.to_date <= end_date.to_date)
            pregnant_women_patient_ids << p['person_id'].to_i
          end
        end
        #########################################################################

        cum_breastfeeding_mothers.each do |w|
          next if pregnant_women_patient_ids.include?(w['person_id'].to_i)

          date_enrolled_str = ActiveRecord::Base.connection.select_one(
            "SELECT date_enrolled FROM temp_earliest_start_date e
             WHERE patient_id = #{w['person_id'].to_i}"
          )

          date_enrolled = date_enrolled_str['date_enrolled'].to_date
          if (date_enrolled >= @cohort_cum_start_date.to_date) && (end_date.to_date <= end_date.to_date)
            fbf_women_patient_ids << w['person_id'].to_i
          end
        end

        (get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |fbf|
          next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)

          started_on_art << { patient_id: fbf['patient_id'].to_i, date_enrolled: fbf['date_enrolled'].to_date }
        end

        (get_alive_on_art(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fbf|
          next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)

          alive_on_art << { patient_id: fbf['patient_id'].to_i }
        end

        (get_started_on_ipt(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fbf|
          next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)

          started_on_ipt << { patient_id: fbf['patient_id'].to_i }
        end

        (get_screened_for_tb(yrs_months, age_from, age_to, gender, @cohort_cum_start_date, end_date) || []).each do |fbf|
          next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)

          screened_for_tb << { patient_id: fbf['patient_id'].to_i }
        end

        [started_on_art, alive_on_art, started_on_ipt, screened_for_tb]
      end
    end
  end
end
