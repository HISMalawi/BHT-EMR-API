# frozen_string_literal: true

module AncService
  module Reports
    # ANC cohort report builder
    class CohortBuilder
      COHORT_LENGTH = 6.months

      PROGRAM = Program.find_by name: 'ANC PROGRAM'

      LAB_RESULTS =       EncounterType.find_by name: 'LAB RESULTS'
      CURRENT_PREGNANCY = EncounterType.find_by name: 'CURRENT PREGNANCY'
      ANC_VISIT_TYPE =    EncounterType.find_by name: 'ANC VISIT TYPE'
      DISPENSING =        EncounterType.find_by name: 'DISPENSING'
      ANC_EXAMINATION =   EncounterType.find_by name: 'ANC EXAMINATION'

      YES = ConceptName.find_by name: 'Yes'
      NO  = ConceptName.find_by name: 'No'
      LMP = ConceptName.find_by name: 'Date of Last Menstrual Period'
      TD = ConceptName.find_by name: 'TT STATUS'
      HB = ConceptName.find_by name: 'HB TEST RESULT'

      WEEK_OF_FIRST_VISIT = ConceptName.find_by name: 'Week of First Visit'
      REASON_FOR_VISIT =    ConceptName.find_by name: 'Reason for visit'
      HIV_TEST_DATE =       ConceptName.find_by name: 'HIV test date'
      PREV_HIV_TEST =       ConceptName.find_by name: 'Previous HIV Test Results'
      PREV_HIV_TEST_DATE =  ConceptName.find_by name: 'Previous HIV Test Date'
      PRE_ECLAMPSIA =       ConceptName.find_by name: 'PRE-ECLAMPSIA'
      HIV_STATUS =          ConceptName.find_by name: 'HIV Status'
      DIAGNOSIS =           ConceptName.find_by name: 'DIAGNOSIS'
      SYPHILIS =            ConceptName.find_by name: 'Syphilis Test Result'
      NEGATIVE =            ConceptName.find_by name: 'Negative'
      POSITIVE =            ConceptName.find_by name: 'Positive'
      NOT_DONE =            ConceptName.find_by name: 'Not Done'
      BED_NET =             ConceptName.find_by name: 'Bed Net'
      ON_ART =              ConceptName.find_by name: 'On ART'

      include ModelUtils

      def build(cohort_struct, start_date, _end_date)
        # Monthly date ranges
        @m_start_date = start_date
        @m_end_date = @m_start_date.to_date.end_of_month

        # Cohort date ranges
        @c_start_date = (@m_start_date.to_date - COHORT_LENGTH)
        @c_end_date = (@m_end_date.to_date - COHORT_LENGTH)

        @today = @m_end_date.to_date

        @start_date = "#{@m_start_date} 00:00:00"
        @end_date = "#{@m_end_date} 23:59:59"

        @m_pregnant_range = (((@m_end_date.to_time - @m_start_date.to_time).round / (3600 * 24)) + 1).days
        @c_pregnant_range = 6.months

        # women registered in a booking cohort
        @cohort_patients = registrations(@c_start_date.to_date.beginning_of_month,
                                         @c_start_date.to_date.end_of_month)

        # women registered in a reporting month
        @monthly_patients = registrations(@m_start_date.to_date.beginning_of_month, @m_end_date.end_of_month)

        c_max_date = ((@c_start_date.to_date + @c_pregnant_range) - 1.day).to_date
        c_min_date = @c_start_date.to_date - 10.months

        m_max_date = ((@m_start_date.to_date + @m_pregnant_range) - 1.day).to_date
        m_min_date = @m_start_date.to_date - 10.months

        @m_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{m_max_date}', '#{m_min_date}')))"

        @c_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{c_max_date}', '#{m_min_date}')))"

        lmp = '(SELECT DATE(MAX(o.value_datetime)) FROM obs o WHERE o.person_id = enc.patient_id '\
              "AND o.concept_id = #{LMP.concept_id} AND DATE(o.obs_datetime) <= '#{c_max_date}' "\
              "AND DATE(o.obs_datetime) >= '#{c_min_date}')"

        visits_query = "SELECT #{lmp} lmp, enc.patient_id patient_id, "\
                        'MAX(ob.value_numeric) form_id FROM encounter enc INNER JOIN obs ob '\
                        'ON ob.encounter_id = enc.encounter_id WHERE enc.program_id = ? AND '\
                        'enc.patient_id IN (?) AND enc.encounter_type = ? AND ob.concept_id = ? AND '\
                        "DATE(enc.encounter_datetime) <= ? AND DATE(enc.encounter_datetime) >= #{lmp} "\
                        'GROUP BY enc.patient_id'

        @anc_visits = Encounter.find_by_sql([visits_query, PROGRAM.id, @cohort_patients, ANC_VISIT_TYPE.id,
                                             REASON_FOR_VISIT.concept_id, c_max_date]).collect do |e|
          [e.patient_id, e.form_id]
        end

        # Indicators for monthly patients in cohort report.
        @patients_done_pregnancy_test = pregnancy_test_done(start_date)
        @pregnancy_test_done_in_first_trim = pregnancy_test_done_in_first_trimester(start_date)
        @first_new_hiv_negative = new_hiv_negative_first_visit(start_date)
        @prev_hiv_neg_first_visit = pre_hiv_negative_first_visit(start_date)
        @prev_hiv_pos_first_visit = prev_hiv_positive_first_visit(start_date)
        @first_new_hiv_positive = new_hiv_positive_first_visit(start_date) - @prev_hiv_pos_first_visit
        @total_hiv_positive_first_visit = (@first_new_hiv_positive + @prev_hiv_pos_first_visit).uniq
        @total_hiv_negative_first_visit = @first_new_hiv_negative + @prev_hiv_neg_first_visit
        @total_tested_in_first_visit = @total_hiv_negative_first_visit + @total_hiv_positive_first_visit
        @not_done_hiv_test_first_visit = @monthly_patients - @total_tested_in_first_visit
        @m_extra_art_checks = extra_art_checks('monthly', m_max_date)
        @m_on_art_in_nart = on_art_in_nart(@total_hiv_positive_first_visit, start_date)
        @on_art_before_anc_first_visit = @m_on_art_in_nart['arv_before_visit_one']
        @start_art_zero_to_twenty_seven_for_first_visit = start_art_zero_to_twenty_seven_for_first_visit(start_date)
        @start_art_plus_twenty_eight_for_first_visit = start_art_plus_twenty_eight_for_first_visit(start_date)
        @total_on_art = (@on_art_before_anc_first_visit + @start_art_zero_to_twenty_seven_for_first_visit +
          @start_art_plus_twenty_eight_for_first_visit).uniq
        @m_not_on_art = @total_hiv_positive_first_visit - @total_on_art

        cohort_struct.monthly_patient = @monthly_patients
        cohort_struct.pregnancy_test_done = @patients_done_pregnancy_test || []
        cohort_struct.pregnancy_test_not_done = (@monthly_patients.uniq - @patients_done_pregnancy_test.uniq).uniq
        cohort_struct.pregnancy_test_done_in_first_trimester = @pregnancy_test_done_in_first_trim
        cohort_struct.pregnancy_test_not_done_in_first_trimester = (@monthly_patients.uniq - @pregnancy_test_done_in_first_trim).uniq
        cohort_struct.week_of_first_visit_zero_to_twelve = week_of_first_visit_zero_to_twelve(start_date)
        cohort_struct.week_of_first_visit_plus_thirteen = week_of_first_visit_plus_thirteen(start_date)
        cohort_struct.new_hiv_negative_first_visit = @first_new_hiv_negative
        cohort_struct.new_hiv_positive_first_visit = @first_new_hiv_positive
        cohort_struct.prev_hiv_positive_first_visit = @prev_hiv_pos_first_visit
        cohort_struct.pre_hiv_negative_first_visit = @prev_hiv_neg_first_visit
        cohort_struct.not_done_hiv_test_first_visit = @not_done_hiv_test_first_visit
        cohort_struct.total_hiv_positive_first_visit = @total_hiv_positive_first_visit

        first_art_start_dates = on_art_before_anc_final(cohort_struct.total_hiv_positive_first_visit)
        cohort_struct.on_art_before_anc_first_visit = first_art_start_dates[:art_before_anc] || []
        cohort_struct.start_art_zero_to_twenty_seven_for_first_visit = first_art_start_dates[:zero_to_twenty_seven_weeks] || []
        cohort_struct.start_art_plus_twenty_eight_for_first_visit = first_art_start_dates[:twenty_eight_plus_weeks] || []
        cohort_struct.not_on_art_first_visit = cohort_struct.total_hiv_positive_first_visit - first_art_start_dates&.values&.flatten || []

        # Indicators for the cohort block
        cohort_struct.total_women_in_cohort = @cohort_patients
        cohort_struct.patients_with_total_of_one_visit = patients_with_total_visits(1) { |y| y == 1 }
        cohort_struct.patients_with_total_of_two_visits = patients_with_total_visits(2) { |y| y == 2 }
        cohort_struct.patients_with_total_of_three_visits = patients_with_total_visits(3) { |y| y == 3 }
        cohort_struct.patients_with_total_of_four_visits = patients_with_total_visits(4) { |y| y == 4 }
        cohort_struct.patients_with_total_of_five_plus_visits = patients_with_total_visits(5) { |y| y >= 5 }
        cohort_struct.patients_with_pre_eclampsia = patients_with_pre_eclampsia
        cohort_struct.patients_without_pre_eclampsia = @cohort_patients - cohort_struct.patients_with_pre_eclampsia

        # TD given
        td_at_least_3 = patients_given_td_at_least_two_doses
        td_less_than_2 = patients_given_td_less_than_two_doses
        td_not_given = @cohort_patients - (td_at_least_3 + td_less_than_2)
        cohort_struct.patients_given_td_less_than_two_doses = td_less_than_2 + td_not_given
        cohort_struct.patients_given_td_at_least_two_doses = td_at_least_3

        # SP Doses given
        sp_one_dose = patients_given_one_sp_dose
        sp_two_doses = patients_given_two_sp_doses
        sp_three_doses = patients_given_three_or_sp_doses
        sp_zero_doses = (@cohort_patients - (sp_one_dose + sp_two_doses + sp_three_doses)).uniq
        cohort_struct.patients_given_zero_sp_doses = sp_zero_doses
        cohort_struct.patients_given_one_sp_dose = sp_one_dose
        cohort_struct.patients_given_two_sp_doses = sp_two_doses
        cohort_struct.patients_given_three_or_more_sp_doses = sp_three_doses

        # Fefol tablets given
        fefol_less_than_120, fefol_120_plus = patients_given_fefol_tablets
        cohort_struct.patients_given_less_than_one_twenty_fefol_tablets = fefol_less_than_120
        cohort_struct.patients_given_one_twenty_plus_fefol_tablets = fefol_120_plus

        # Albendazole
        cohort_struct.patients_given_one_albendazole_dose = patients_given_one_albendazole_dose
        cohort_struct.patients_not_given_albendazole_doses = (@cohort_patients - patients_given_one_albendazole_dose).uniq

        # Bed nets
        cohort_struct.patients_not_given_bed_net = patients_not_given_bed_net
        cohort_struct.patients_given_bed_net = patients_given_bed_net

        # HB Tests
        hb_less_than_7 = patients_have_hb_less_than_7_g_dl
        hb_at_least_7 = patients_have_hb_greater_than_6_g_dl
        cohort_struct.patients_have_hb_less_than_7_g_dl = hb_less_than_7
        cohort_struct.patients_have_hb_greater_than_6_g_dl = hb_at_least_7
        cohort_struct.patients_hb_test_not_done = @cohort_patients - (hb_at_least_7 + hb_less_than_7)

        # Syphilis Tests
        syphil_neg = patients_with_negative_syphilis_status
        syphil_pos = patients_with_positive_syphilis_status
        syphil_unk = @cohort_patients - (syphil_neg + syphil_pos)
        cohort_struct.patients_with_negative_syphilis_status = syphil_neg
        cohort_struct.patients_with_positive_syphilis_status = syphil_pos
        cohort_struct.patients_with_unknown_syphilis_status = syphil_unk

        final_statuses = c_patients_hiv_statuses

        cohort_struct.new_hiv_negative_final_visit = final_statuses[:new_negative] || []
        cohort_struct.prev_hiv_positive_final_visit = final_statuses[:prev_positive] || []
        cohort_struct.new_hiv_positive_final_visit = final_statuses[:new_positive] || []
        cohort_struct.pre_hiv_negative_final_visit = final_statuses[:prev_negative] || []
        cohort_struct.not_done_hiv_test_final_visit = final_statuses[:not_done] || []
        cohort_struct.c_total_hiv_positive = cohort_struct.new_hiv_positive_final_visit + cohort_struct.prev_hiv_positive_final_visit

        on_art_final = patients_on_art_final_visit(cohort_struct.c_total_hiv_positive)

        cohort_struct.not_on_art_final_visit = cohort_struct.c_total_hiv_positive - on_art_final
        final_art_start_dates = on_art_before_anc_final(on_art_final)
        cohort_struct.on_art_before_anc_final_visit = final_art_start_dates[:art_before_anc] || []
        cohort_struct.start_art_zero_to_twenty_seven_for_final_visit = final_art_start_dates[:zero_to_twenty_seven_weeks] || []
        cohort_struct.start_art_plus_twenty_eight_for_final_visit = final_art_start_dates[:twenty_eight_plus_weeks] || []

        cohort_struct.on_cpt = patients_final_on_cpt(cohort_struct.c_total_hiv_positive)
        cohort_struct.not_on_cpt = cohort_struct.c_total_hiv_positive - cohort_struct.on_cpt
        cohort_struct.nvp_given = patients_final_given_nvp(cohort_struct.c_total_hiv_positive)
        cohort_struct.nvp_not_given = cohort_struct.c_total_hiv_positive - cohort_struct.nvp_given

        cohort_struct
      end

      def patients_with_total_visits(_visit_count)
        @anc_visits.select { |_x, y| yield(y) }.collect { |x, _y| x }.uniq
      end

      def patients_final_on_cpt(positive_patients)
        return [] unless positive_patients.present?

        Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e
              INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			        WHERE e.encounter_type = (?)
			        AND o.value_drug IN (
                 SELECT drug_id FROM drug WHERE name LIKE '%Cotrimoxazole%'
              ) AND e.patient_id IN (#{positive_patients.join(',')}) AND
              e.encounter_datetime <= ? GROUP BY e.patient_id", DISPENSING.id, @end_date.to_date\
              .end_of_month.strftime('%Y-%m-%d 23:59:59')])\
                 .map(&:patient_id)
      end

      def patients_final_given_nvp(positive_patients)
        return [] unless positive_patients.present?

        Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e
              INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			        WHERE e.encounter_type = (?)
			        AND o.value_drug IN (
                SELECT drug_id FROM drug WHERE name LIKE '%Nevirapine%'
                OR name LIKE '%NVP%'
              )
              AND e.patient_id IN (#{positive_patients.join(',')}) AND
              e.encounter_datetime <= ?
              GROUP BY e.patient_id", DISPENSING.id, @end_date.to_date\
              .end_of_month.strftime('%Y-%m-%d 23:59:59')])\
                 .map(&:patient_id)
      end

      def on_art_before_anc_final(patients_on_art)
        return {} unless patients_on_art.present?

        art_before_anc = []
        zero_to_twenty_seven_weeks = []
        twenty_eight_plus_weeks = []

        patients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            e.patient_id,
            COALESCE(max(hiv_status.obs_datetime), max(pre.value_datetime), t.date_enrolled) date_hiv_status_recorded,
            first_visit.max_encounter date_first_visit
            FROM encounter e
            LEFT JOIN obs hiv_status on hiv_status.encounter_id = e.encounter_id
              AND hiv_status.concept_id = #{HIV_STATUS.concept_id}
              AND hiv_status.voided = 0
            LEFT JOIN obs pre on pre.encounter_id = e.encounter_id
              AND pre.concept_id = #{PREV_HIV_TEST_DATE.concept_id}
              AND pre.voided = 0
            LEFT JOIN (
              SELECT e.patient_id, e.encounter_datetime max_encounter
              FROM encounter e
              INNER JOIN obs o ON e.encounter_id = o.encounter_id
              WHERE e.voided = 0
              AND e.encounter_type = #{CURRENT_PREGNANCY.id}
            ) first_visit ON first_visit.patient_id = e.patient_id
            LEFT JOIN temp_earliest_start_date t ON t.patient_id = e.patient_id
              AND t.date_enrolled < '#{@end_date}'
            WHERE e.patient_id IN(#{patients_on_art.join(',')})
          GROUP BY e.patient_id
        SQL

        patients.each do |p|
          hiv_status_date = p['date_hiv_status_recorded']&.to_date
          first_visit_date = p['date_first_visit']&.to_date

          art_before_anc << p['patient_id'] && next if hiv_status_date < first_visit_date

          if hiv_status_date >= first_visit_date && \
             hiv_status_date < first_visit_date + 27.weeks
            zero_to_twenty_seven_weeks << p['patient_id']
            next
          end

          if hiv_status_date >= first_visit_date + 28.weeks
            twenty_eight_plus_weeks << p['patient_id']
            next
          end
        end

        {
          art_before_anc:,
          zero_to_twenty_seven_weeks:,
          twenty_eight_plus_weeks:
        }
      end

      def patients_on_art_final_visit(positive_patients)
        return [] unless positive_patients.present?

        data = ActiveRecord::Base.connection.select_all <<~SQL

          SELECT person_id AS patient_id
          FROM obs
          WHERE person_id IN (#{positive_patients.join(',')})
            AND concept_id = #{ON_ART.concept_id}
            AND value_coded = #{YES.concept_id}
            AND voided = 0

          UNION

          SELECT person_id AS patient_id
          FROM obs
          WHERE person_id IN (#{positive_patients.join(',')})
            AND concept_id = #{PREV_HIV_TEST.concept_id}
            AND value_coded = #{POSITIVE.concept_id}
            AND voided = 0

          UNION

          SELECT patient_id
          FROM temp_earliest_start_date
          WHERE date_enrolled < '2024-06-30 23:59:59'
            AND patient_id IN (#{positive_patients.join(',')})
        SQL

        data.map { |d| d['patient_id'] }
      end
      # private

      # Get women registered within a specified period
      def registrations(start_dt, end_dt)
        Encounter.joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
                 .where(['program_id = ? AND encounter_type = ? AND obs.concept_id = ? AND
              DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND encounter.voided = 0',
                         PROGRAM.id, CURRENT_PREGNANCY.id, LMP.concept_id, start_dt.to_date, end_dt.to_date]).collect(&:patient_id).uniq
      end

      def pregnancy_test_done(_date)
        preg_test = ConceptName.find_by name: 'Pregnancy test'

        Encounter.joins(:observations).where("encounter.program_id = ?
            AND encounter.encounter_type = ? AND obs.concept_id = ?
            AND value_coded = ? AND encounter.patient_id in (?)",
                                             PROGRAM.id, LAB_RESULTS.id, preg_test.concept_id, YES.concept_id,
                                             @monthly_patients).collect(&:patient_id).compact.uniq
      end

      def pregnancy_test_done_in_first_trimester(date)
        Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM
              encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
              AND o.concept_id = ? AND encounter.voided = 0
              WHERE program_id = ? AND DATE(encounter_datetime) BETWEEN
              (SELECT DATE(MIN(lmp)) FROM last_menstraul_period_date
              WHERE person_id IN (?) AND obs_datetime BETWEEN ? and ?)
              AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk < 13',
                               WEEK_OF_FIRST_VISIT.concept_id, PROGRAM.id,
                               @patients_done_pregnancy_test,
                               date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                               date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                               date.to_date, @patients_done_pregnancy_test]).collect(&:patient_id).uniq
      end

      def week_of_first_visit_zero_to_twelve(date)
        Encounter.find_by_sql(["SELECT patient_id, o.value_numeric wk FROM encounter
              INNER JOIN obs o ON o.encounter_id = encounter.encounter_id AND o.concept_id = ?
              AND encounter.voided = 0 WHERE program_id = ? AND patient_id IN (?)
              AND DATE(encounter_datetime) BETWEEN (?) AND (?) GROUP BY patient_id HAVING wk < 13",
                               WEEK_OF_FIRST_VISIT.concept_id, PROGRAM.id, @monthly_patients,
                               date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                               date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).collect(&:patient_id).uniq
      end

      def week_of_first_visit_plus_thirteen(date)
        Encounter.find_by_sql(["SELECT patient_id, o.value_numeric wk FROM encounter
              INNER JOIN obs o ON o.encounter_id = encounter.encounter_id AND o.concept_id = ?
              AND encounter.voided = 0 WHERE program_id = ? AND patient_id IN (?) AND DATE(encounter_datetime)
              BETWEEN (?) AND (?) GROUP BY patient_id HAVING wk > 12",
                               WEEK_OF_FIRST_VISIT.concept_id, PROGRAM.id, @monthly_patients,
                               date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                               date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).collect(&:patient_id).uniq
      end

      def new_hiv_negative_first_visit(date)
        Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o ON
            o.encounter_id = e.encounter_id AND e.voided = 0
            WHERE e.program_id = ? AND o.concept_id = ? AND ((o.value_coded = ?) OR (o.value_text = 'Negative'))
            AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND
            e.encounter_datetime <= ?", PROGRAM.id, HIV_STATUS.concept_id, NEGATIVE.concept_id,
                               @monthly_patients, date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                               date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id).uniq
      end

      def new_hiv_positive_first_visit(date)
        new_pos = Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
            WHERE e.program_id = ? AND o.concept_id = ? AND ((o.value_coded = ?)
              OR (o.value_text = 'Positive')) AND e.patient_id IN (?)
            AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
            INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = ?
            WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
            AND DATE(encounter.encounter_datetime) <= ?)
            AND (DATE(e.encounter_datetime) <= ?)
            GROUP BY e.patient_id", PROGRAM.id, HIV_STATUS.concept_id,
                                         POSITIVE.concept_id, @monthly_patients, HIV_STATUS.concept_id,
                                         date.to_date.end_of_month, date.to_date.end_of_month]).map(&:patient_id)

        (new_pos + new_positive_same_facility_art(date)).uniq
      end

      def prev_hiv_positive_first_visit(date)
        prev_pos = Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o ON
                o.encounter_id = e.encounter_id AND e.voided = 0
                WHERE e.program_id = ? AND o.concept_id = ?
                AND ((o.value_coded = ?) OR (o.value_text = 'Negative'))
                AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND
                e.encounter_datetime <= ?", PROGRAM.id, PREV_HIV_TEST.concept_id,
                                          POSITIVE.concept_id, @monthly_patients,
                                          date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                                          date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)

        (prev_pos + prev_positive_same_facility_art(date)).uniq
      end

      def pre_hiv_negative_first_visit(date)
        prev_neg = Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e
                        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
                        WHERE o.concept_id = ? AND ((o.value_coded = ?) OR (o.value_text = 'Negative'))
                        AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND
                        e.encounter_datetime <= ?", PREV_HIV_TEST.concept_id, NEGATIVE.concept_id,
                                          @monthly_patients,
                                          date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                                          date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)
        (prev_neg - @first_new_hiv_negative)
      end

      def prev_positive_same_facility_art(date)
        Encounter.find_by_sql(["
                    SELECT e.patient_id
                    FROM encounter e
                    INNER JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id = 7882 /*Confirmatory Test date*/
                    WHERE o.value_datetime < '#{date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')}'
                    AND o.voided = 0 AND e.voided = 0
                    AND e.program_id = 1 AND e.encounter_type = 9 /*Clinic registration*/
                    AND e.patient_id IN (?)", @monthly_patients]).map(&:patient_id)
      end

      def new_positive_same_facility_art(date)
        Encounter.find_by_sql(["
                    SELECT e.patient_id
                    FROM encounter e
                    INNER JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id = 7882 /*Confirmatory Test date*/
                    WHERE o.value_datetime >= '#{date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00')}'
                    AND o.voided = 0 AND e.voided = 0
                    AND o.value_datetime <= '#{date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')}'
                    AND e.program_id = 1 AND e.encounter_type = 9 /*Clinic registration*/
                    AND e.patient_id IN (?)", @monthly_patients]).map(&:patient_id)
      end

      def extra_art_checks(type, date)
        concept_ids = ['Reason for exiting care', 'On ART'].collect { |c| ConceptName.find_by_name(c).concept_id }
        encounter_types = ['LAB RESULTS', 'ART_FOLLOWUP'].collect { |t| EncounterType.find_by_name(t).id }
        art_answers = ['Yes', 'Already on ART at another facility']

        result = []

        if type == 'monthly'

          result = begin
            Encounter.find_by_sql(['SELECT e.patient_id FROM encounter e
                                           INNER JOIN obs o on o.encounter_id = e.encounter_id
                                           WHERE e.voided = 0 AND e.program_id = ? AND e.patient_id IN (?)
                                           AND e.encounter_type IN (?) AND o.concept_id IN (?)
                                           AND DATE(e.encounter_datetime) <= ? AND COALESCE(
                                           (SELECT name FROM concept_name WHERE concept_id = o.value_coded LIMIT 1),
                                           o.value_text) IN (?)', PROGRAM.id,
                                   ([0] + @monthly_patients), encounter_types, concept_ids, date,
                                   art_answers]).map(&:patient_id)
          rescue StandardError
            []
          end

        end

        result.uniq
      end

      def on_art_in_nart(positive_patients, date)
        id_visit_map = []
        anc_visit = {}
        positive_patients.each do |id|
          next if id.nil?

          d = Observation.find_by_sql(['SELECT MAX(value_datetime) as date FROM obs
                    JOIN encounter ON obs.encounter_id = encounter.encounter_id
                    AND encounter.program_id = ? WHERE encounter.encounter_type = ?
                    AND person_id = ? AND concept_id = ?', PROGRAM.id,
                                       CURRENT_PREGNANCY.id, id, LMP.concept_id])
                         .first.date.strftime('%Y-%m-%d') # rescue nil

          value = "#{id}|#{d}" unless d.nil?
          id_visit_map << value unless d.nil?
          anc_visit[id] = d unless d.nil?
        end

        result = {}
        patient_ids = []
        b4_visit_one = []
        cpt_ids = []

        if positive_patients.length.positive?
          art_patients = ActiveRecord::Base.connection.select_all <<~SQL
            SELECT patient_id, earliest_start_date FROM temp_earliest_start_date
            WHERE gender = 'F' AND death_date IS NULL
            AND DATE(date_enrolled) <= '#{date.to_date}'
            AND patient_id IN (#{positive_patients.join(',')})
          SQL
          art_patients.each do |patient|
            patient_ids << patient['patient_id']
            earliest_start_date = patient['earliest_start_date'].to_date
            result[(patient['patient_id']).to_s] = patient['earliest_start_date'].to_date.strftime('%Y-%m-%d')
            next unless begin
              earliest_start_date.to_date < anc_visit[patient['patient_id']].to_date
            rescue StandardError
              false
            end

            b4_visit_one << patient['patient_id']
          end
        end

        no_art = id_visit_map - result.keys

        if patient_ids.length.positive?

          cpt_ids = Encounter.find_by_sql(["SELECT * FROM encounter e
              INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			        WHERE e.encounter_type = (?)
			        AND o.value_drug IN (?) AND e.patient_id IN (?) AND
              e.encounter_datetime <= ?", DISPENSING.id, Drug.where(['name LIKE ?', '%Cotrimoxazole%']).map(&:id).join(','),
                                           patient_ids.join(','),
                                           date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)
        end

        result['on_cpt'] = cpt_ids.blank? ? [] : cpt_ids.join(',')
        result['arv_before_visit_one'] = b4_visit_one.blank? ? [] : b4_visit_one # .join(",")

        result['no_art'] = no_art.join(',')
        result
      end

      def start_art_zero_to_twenty_seven_for_first_visit(date)
        remote = []
        Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            AND encounter.voided = 0 AND encounter.program_id = ?
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@m_lmp} AND ?", PROGRAM.id, LMP.concept_id,
                                 @total_hiv_positive_first_visit, date.to_date.end_of_month]).collect do |ob|
          ident = ob.person_id
          # raise ident.inspect
          next unless !ob.value_datetime.blank? && @m_on_art_in_nart[ident.to_s]

          start_date = @m_on_art_in_nart[ident.to_s].to_date
          lmp = ob.value_datetime.to_date
          if  (start_date >= lmp) && (start_date < (lmp + 28.weeks)) && !remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end

        remote = [] if remote.to_s.blank?

        (remote - @m_extra_art_checks)
      end

      def start_art_plus_twenty_eight_for_first_visit(date)
        remote = []
        Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            AND encounter.voided = 0 AND encounter.program_id = ?
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@m_lmp} AND ?", PROGRAM.id, LMP.concept_id,
                                 @total_hiv_positive_first_visit, date.to_date.end_of_month]).collect do |ob|
          ident = ob.person_id
          # raise ident.inspect
          next unless !ob.value_datetime.blank? && @m_on_art_in_nart[ident.to_s]

          start_date = @m_on_art_in_nart[ident.to_s].to_date
          lmp = ob.value_datetime.to_date

          remote << ob.person_id if start_date >= (lmp + 28.weeks) && !remote.include?(ob.person_id)
        end

        remote = [] if remote.to_s.blank?

        (remote - @m_extra_art_checks)
      end

      def patients_with_pre_eclampsia
        Encounter.joins([:observations])
                 .where(['program_id = ? AND encounter_type = ?
                          AND concept_id = ? AND value_coded = ? AND DATE(encounter_datetime) '\
              "BETWEEN (#{@c_lmp}) AND (?) AND encounter.patient_id IN (?)",
                         PROGRAM.id, ANC_EXAMINATION.id, PRE_ECLAMPSIA.concept_id, YES.concept_id,
                         (@c_start_date.to_date + @c_pregnant_range),
                         @cohort_patients]).collect(&:patient_id).uniq
      end

      def patients_given_td_less_than_two_doses
        patients = {}

        Order.joins([[drug_order: :drug], :encounter])
             .where(['encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= ? '\
              'AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) '\
              'AND orders.voided = 0', PROGRAM.id, '%TD%', @c_lmp,
                     ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                     @cohort_patients])
             .group([:patient_id])
             .select(['encounter.patient_id, count(*) encounter_id']).collect do |o|
          [o.patient_id, o.encounter_id]
        end.delete_if do |p, e|
          v = 0
          v = patients[p] if patients[p]
          v.to_i + e.to_i < 2
        end.collect { |x, _y| x }.uniq
      end

      def patients_given_td_at_least_two_doses
        patients = {}

        Order.joins([[drug_order: :drug], :encounter])
             .where(['encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= ? '\
              'AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) '\
              'AND orders.voided = 0', PROGRAM.id, '%TD%', @c_lmp,
                     ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                     @cohort_patients])
             .group([:patient_id])
             .select(['encounter.patient_id, count(*) encounter_id']).collect do |o|
          [o.patient_id, o.encounter_id]
        end.delete_if do |p, e|
          v = 0
          v = patients[p] if patients[p]
          v.to_i + e.to_i > 1
        end.collect { |x, _y| x }.uniq
      end

      def patients_given_zero_to_two_sp_doses
        Order.where('encounter.program_id = ? AND (drug.name = ? OR drug.name = ?) AND DATE(encounter_datetime) <= ? '\
              'AND encounter.patient_id IN (?)',
                    'Sulphadoxine and Pyrimenthane (25mg tablet)', 'SP (3 tablets)',
                    PROGRAM.id, ((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
             .joins([[drug_order: :drug], :encounter])
             .select(['encounter.patient_id, count(encounter.encounter_id) as count, '\
              'encounter_datetime, drug.name instructions'])
             .group([:patient_id]).collect do |o|
          [o.patient_id, o.count]
        end.compact.delete_if { |_x, y| y.to_i > 2 }.collect { |p, _c| p }.uniq
      end

      def patients_given_one_sp_dose
        patient_sp_doses.collect { |p| p['patient_id'] if p['count'].to_i == 1 }.compact
      end

      def patients_given_two_sp_doses
        patient_sp_doses.collect { |p| p['patient_id'] if p['count'].to_i == 2 }.compact
      end

      def patients_given_three_or_sp_doses
        patient_sp_doses.collect { |p| p['patient_id'] if p['count'].to_i >= 3 }.compact
      end

      def patient_sp_doses
        return [] unless @cohort_patients.any?

        @patient_sp_doses ||= ActiveRecord::Base.connection.select_all <<~SQL
          SELECT encounter.patient_id, count(encounter.encounter_id) as count
          FROM orders o
          INNER JOIN encounter ON o.encounter_id = encounter.encounter_id
          AND encounter.voided = 0 AND encounter.program_id = #{PROGRAM.id}
          INNER JOIN concept_name ON o.concept_id = concept_name.concept_id AND concept_name.voided = 0 AND concept_name.name = 'Sulfadoxine and Pyrimethamine'
          INNER JOIN drug_order ON o.order_id = drug_order.order_id AND drug_order.quantity > 0
          WHERE DATE(encounter_datetime) <= '#{@c_start_date.to_date + @c_pregnant_range - 1.day}' AND encounter.patient_id IN (#{@cohort_patients.join(',')})
          AND encounter.program_id = #{PROGRAM.id}
          GROUP BY encounter.patient_id
        SQL
      end

      def patients_given_at_least_three_sp_doses
        Order.where('encounter.program_id = ? AND (drug.name = ? OR drug.name = ?) '\
              'AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)',
                    PROGRAM.id, 'Sulphadoxine and Pyrimenthane (25mg tablet)', 'SP (3 tablets)',
                    ((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
             .joins([[drug_order: :drug], :encounter])
             .select(['encounter.patient_id, count(encounter.encounter_id) as count, '\
              'encounter_datetime, drug.name instructions'])
             .group([:patient_id]).collect do |o|
          [o.patient_id, o.count]
        end.compact.delete_if { |_x, y| y.to_i < 3 }.collect { |p, _c| p }.uniq
      end

      def patients_given_fefol_tablets
        fefol = {}
        plus_120 = []
        Order.joins([[drug_order: :drug], :encounter])
             .where(["encounter.program_id = ? AND drug.name = ? AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", PROGRAM.id,
                     'Fefol (1 tablet)', ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                     @cohort_patients])
             .group([:patient_id]).select(["encounter.patient_id, count(*) datetime,
                drug.name instructions,COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"])
             .each do |o|
          fefol[o.patient_id] = o.orderer # if ! fefol[o.patient_id].include?(o.datetime)
        end

        plus_120 = fefol.keys if fefol.values.any? { |v| v.to_i >= 120 }

        # the total has to match the cohort patients
        # get the rest of the cohort patients as < 120
        minus_120 = @cohort_patients - plus_120

        [minus_120, plus_120]
      end

      def patients_given_one_albendazole_dose
        Order.joins([[drug_order: :drug], :encounter])
             .where(["encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= #{@c_lmp}
                    AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", PROGRAM.id,
                     '%albendazole%', (@c_start_date.to_date + @c_pregnant_range), @cohort_patients])
             .select(["encounter.patient_id, encounter.encounter_id, drug.name instructions,
                    SUM(DATEDIFF(orders.auto_expire_date, orders.start_date)) orderer"])
             .group('encounter.patient_id')
             .pluck(:patient_id)
      end

      def patients_not_given_bed_net
        given_bed_net = patients_given_bed_net
        @cohort_patients - given_bed_net
      end

      def patients_given_bed_net
        Encounter.joins([:observations])
                 .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                  AND (value_text = 'Yes' OR value_coded = ?
                  OR value_text IN ('Given Today', 'Given during previous ANC visit for current pregnancy'))
                  AND ( DATE(encounter_datetime) >= #{@c_lmp} AND DATE(encounter_datetime) <= ?)
                  AND encounter.patient_id IN (?)", PROGRAM.id, CURRENT_PREGNANCY.id,
                         BED_NET.concept_id, YES.concept_id,
                         (@c_start_date.to_date + @c_pregnant_range), @cohort_patients])
                 .collect(&:patient_id).uniq # rescue []
      end

      def patients_have_hb_less_than_7_g_dl
        Encounter.joins([:observations])
                 .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_text < 7 OR value_numeric < 7)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                         PROGRAM.id, LAB_RESULTS.id, HB.concept_id,
                         ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                         @cohort_patients]).select(['DISTINCT patient_id']).collect(&:patient_id).uniq
      end

      def patients_have_hb_greater_than_6_g_dl
        Encounter.joins([:observations])
                 .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_text >= 7 OR value_numeric >= 7)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                         PROGRAM.id, LAB_RESULTS.id, HB.concept_id,
                         ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                         @cohort_patients])
                 .select(['DISTINCT patient_id']).collect(&:patient_id).uniq
      end

      def patients_with_negative_syphilis_status
        Encounter.joins([:observations])
                 .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_coded = ? OR value_text = ?)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                         PROGRAM.id, LAB_RESULTS.id, SYPHILIS.concept_id, NEGATIVE.concept_id,
                         'Negative', ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                         @cohort_patients])
                 .select(['DISTINCT patient_id']).collect(&:patient_id)
      end

      def patients_with_positive_syphilis_status
        Encounter.joins([:observations])
                 .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_coded = ? OR value_text = ?)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                         PROGRAM.id, LAB_RESULTS.id, SYPHILIS.concept_id, POSITIVE.concept_id,
                         'Positive', ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                         @cohort_patients])
                 .select(['DISTINCT patient_id']).collect(&:patient_id)
      end

      def c_patients_hiv_statuses
        hiv_statuses = {
          prev_negative: [],
          prev_positive: [],
          new_negative: [],
          new_positive: [],
          not_done: []
        }

        return hiv_statuses unless @cohort_patients.any?

        data = ActiveRecord::Base.connection.select_all <<~SQL
                          SELECT e.patient_id, prev_hiv_results, first_visit.hiv_status first_hiv_status, first_visit.date_tested, final_test.final_status, final_test.final_tested_date
              FROM encounter e
              INNER JOIN (
                  SELECT fv.patient_id, pre_results.prev_hiv_results, hiv_status_obs.hiv_status, hiv_status_obs.date_tested
                  FROM encounter fv
                      INNER JOIN obs ob ON ob.person_id = fv.patient_id
                      AND fv.voided = 0
                      AND ob.voided = 0
                  LEFT JOIN (
                      SELECT hs.patient_id, MIN(o.value_coded) hiv_status, MIN(hs.encounter_datetime) date_tested
                          FROM encounter hs
                      INNER JOIN obs o ON o.person_id = hs.patient_id
                          AND hs.voided = 0
                          AND o.voided = 0
                          WHERE hs.encounter_type = #{CURRENT_PREGNANCY.id}
                          AND o.concept_id = #{HIV_STATUS.concept_id}
                            AND hs.program_id = #{PROGRAM.id}
                          AND DATE(hs.encounter_datetime) >= DATE('#{@c_start_date}')
                      GROUP BY hs.patient_id
                  ) as hiv_status_obs ON hiv_status_obs.patient_id = fv.patient_id
                  LEFT JOIN (
                       SELECT hs.patient_id, MIN(o.value_coded) prev_hiv_results
                          FROM encounter hs
                      INNER JOIN obs o ON o.encounter_id = hs.encounter_id
                          AND hs.voided = 0
                          AND o.voided = 0
                          WHERE hs.encounter_type = #{LAB_RESULTS.id}
                            AND hs.program_id = #{PROGRAM.id}
                          AND o.concept_id = #{PREV_HIV_TEST.concept_id}
                          AND DATE(hs.encounter_datetime) >= DATE('#{@c_start_date}')
                          AND DATE(hs.encounter_datetime) <= DATE('#{@end_date}')
                      GROUP BY hs.patient_id
                  ) as pre_results ON pre_results.patient_id = fv.patient_id
                  WHERE DATE(fv.encounter_datetime) <= DATE('#{@end_date}')
                  AND ob.concept_id = #{WEEK_OF_FIRST_VISIT.concept_id}
                    AND fv.encounter_type = #{LAB_RESULTS.id}
                  AND fv.program_id = #{PROGRAM.id}
              ) as first_visit on first_visit.patient_id = e.patient_id
              LEFT JOIN (
                  SELECT e.patient_id, MAX(f.value_coded) final_status, MAX(e.encounter_datetime) final_tested_date
                      FROM encounter e
                      INNER JOIN obs f on f.encounter_id = e.encounter_id
                         AND e.voided = 0
                         AND f.voided = 0
                      WHERE f.concept_id = #{HIV_STATUS.concept_id}
                        AND e.encounter_type = #{LAB_RESULTS.id}
                      AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
                      AND DATE(e.encounter_datetime) >= DATE('#{@c_start_date}')
                      AND e.program_id = #{PROGRAM.id}
                      GROUP BY e.patient_id
              ) as final_test on final_test.patient_id = e.patient_id
                  AND final_test.final_tested_date > first_visit.date_tested
              AND DATE(e.encounter_datetime) <= DATE('#{@end_date}')
              AND DATE(e.encounter_datetime) >= DATE('#{@c_start_date}')
              AND e.program_id = #{PROGRAM.id}
              WHERE e.patient_id IN (#{@cohort_patients.join(',')})
              AND e.voided = 0
          group by e.patient_id
        SQL

        data&.each do |d|
          hiv_statuses[:prev_positive] << d['patient_id'] if d['prev_hiv_results'] == POSITIVE.concept_id

          if d['first_hiv_status'] == NEGATIVE.concept_id && [nil, NOT_DONE.concept_id].include?(d['final_status'])
            hiv_statuses[:prev_negative] << d['patient_id']
          elsif d['prev_hiv_results'] == NEGATIVE.concept_id && [nil, NOT_DONE.concept_id].include?(d['final_status'])
            hiv_statuses[:prev_negative] << d['patient_id']
          elsif d['prev_hiv_results'] == POSITIVE.concept_id && [nil, NOT_DONE.concept_id].include?(d['final_status'])
            hiv_statuses[:prev_positive] << d['patient_id']
          elsif d['first_hiv_status'] == POSITIVE.concept_id && d['final_status'] == POSITIVE.concept_id
            hiv_statuses[:new_positive] << d['patient_id']
          elsif d['first_hiv_status'] == NEGATIVE.concept_id && d['final_status'] == NEGATIVE.concept_id
            hiv_statuses[:new_negative] << d['patient_id']
          elsif d['first_hiv_status'] == POSITIVE.concept_id && [nil, NOT_DONE.concept_id].include?(d['final_status'])
            hiv_statuses[:prev_positive] << d['patient_id']
          elsif d['first_hiv_status'] == NEGATIVE.concept_id && d['final_status'] == POSITIVE.concept_id
            hiv_statuses[:new_positive] << d['patient_id']
          else
            hiv_statuses[:not_done] << d['patient_id']
          end
        end
        hiv_statuses.transform_values(&:uniq)
      end
    end
  end
end
