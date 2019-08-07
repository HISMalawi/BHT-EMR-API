# frozen_string_literal: true

module ANCService
    module Reports
      class CohortBuilder
        COHORT_LENGTH = 6.months

        PROGRAM = Program.find_by name: "ANC PROGRAM"

        LAB_RESULTS =       EncounterType.find_by name: "LAB RESULTS"
        CURRENT_PREGNANCY = EncounterType.find_by name: "CURRENT PREGNANCY"
        ANC_VISIT_TYPE =    EncounterType.find_by name: "ANC VISIT TYPE"
        DISPENSING =        EncounterType.find_by name: "DISPENSING"

        YES = ConceptName.find_by name: "Yes"
        NO  = ConceptName.find_by name: "No"
        LMP = ConceptName.find_by name: "Date of Last Menstrual Period"
        TTV = ConceptName.find_by name: "TT STATUS"
        HB  = ConceptName.find_by name: "HB TEST RESULT"

        WEEK_OF_FIRST_VISIT = ConceptName.find_by name: "Week of First Visit"
        REASON_FOR_VISIT =    ConceptName.find_by name: "Reason for visit"
        HIV_TEST_DATE =       ConceptName.find_by name: "HIV test date"
        PREV_HIV_TEST =       ConceptName.find_by name: "Previous HIV Test Results"
        PRE_ECLAMPSIA =       ConceptName.find_by name: "PRE-ECLAMPSIA"
        HIV_STATUS =          ConceptName.find_by name: "HIV Status"
        DIAGNOSIS =           ConceptName.find_by name: "DIAGNOSIS"
        SYPHILIS =            ConceptName.find_by name: "Syphilis Test Result"
        NEGATIVE =            ConceptName.find_by name: "Negative"
        POSITIVE =            ConceptName.find_by name: "Positive"
        BED_NET =             ConceptName.find_by name: "Bed Net"


        include ModelUtils

        def build(cohort_struct, start_date, end_date)

          # Monthly date ranges
          @m_start_date = start_date
          @m_end_date = @m_start_date.to_date.end_of_month

          # Cohort date ranges
          @c_start_date = (@m_start_date.to_date - COHORT_LENGTH)
          @c_end_date = (@m_end_date.to_date - COHORT_LENGTH)

          @today = @m_end_date.to_date

          @start_date = "#{@m_start_date} 00:00:00"
          @end_date = "#{@m_end_date} 23:59:59"

          @m_pregnant_range = (((@m_end_date.to_time - @m_start_date.to_time).round/(3600*24)) + 1).days
          @c_pregnant_range = 6.months

         # @monthly_patients = registrations(start_date.beginning_of_month, start_date.end_of_month)
          #@cohort_patients = total_patients(start_date, 'cohort')

          # women registered in a booking cohort
          @cohort_patients = registrations(@c_start_date.to_date.beginning_of_month,
                                            @c_start_date.to_date.end_of_month)

          # women registered in a reporting month
          @monthly_patients = registrations(@m_start_date.beginning_of_month, @m_end_date.end_of_month)


          c_max_date = ((@c_start_date.to_date + @c_pregnant_range) - 1.day).to_date
          c_min_date = @c_start_date.to_date - 10.months

          m_max_date = ((@m_start_date.to_date + @m_pregnant_range) - 1.day).to_date
          m_min_date = @m_start_date.to_date - 10.months

          @m_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{m_max_date.to_s}', '#{m_min_date.to_s}')))"

          @c_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{c_max_date.to_s}', '#{m_min_date.to_s}')))"

          lmp = "(SELECT DATE(MAX(o.value_datetime)) FROM obs o WHERE o.person_id = enc.patient_id "\
                "AND o.concept_id = #{LMP.concept_id} AND DATE(o.obs_datetime) <= '#{c_max_date.to_s}' "\
                "AND DATE(o.obs_datetime) >= '#{c_min_date.to_s}')"

          visits_query = "SELECT #{lmp} lmp, enc.patient_id patient_id, "\
                          "MAX(ob.value_numeric) form_id FROM encounter enc INNER JOIN obs ob "\
                          "ON ob.encounter_id = enc.encounter_id WHERE enc.program_id = ? AND "\
                          "enc.patient_id IN (?) AND enc.encounter_type = ? AND ob.concept_id = ? AND "\
                          "DATE(enc.encounter_datetime) <= ? AND DATE(enc.encounter_datetime) >= #{lmp} "\
                          "GROUP BY enc.patient_id"

          @anc_visits = Encounter.find_by_sql([visits_query, PROGRAM.id, @cohort_patients,ANC_VISIT_TYPE.id,
                          REASON_FOR_VISIT.concept_id, c_max_date]).collect { |e|
                          [e.patient_id, e.form_id]
                        }


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
          @m_extra_art_checks = extra_art_checks("monthly", m_max_date)
          @m_on_art_in_nart = on_art_in_nart(start_date)
          @m_on_art_before  = @m_on_art_in_nart["arv_before_visit_one"]
          @on_art_before_anc_first_visit = on_art_before_anc_first_visit(start_date)
          @start_art_zero_to_twenty_seven_for_first_visit = start_art_zero_to_twenty_seven_for_first_visit(start_date)
          @start_art_plus_twenty_eight_for_first_visit = start_art_plus_twenty_eight_for_first_visit(start_date)
          @total_on_art = (@on_art_before_anc_first_visit + @start_art_zero_to_twenty_seven_for_first_visit +
            @start_art_plus_twenty_eight_for_first_visit).uniq
          @m_not_on_art = @total_hiv_positive_first_visit - @total_on_art

          #raise @m_on_art_in_nart.inspect

          cohort_struct.monthly_patient = @monthly_patients
          cohort_struct.pregnancy_test_done = @patients_done_pregnancy_test
          cohort_struct.pregnancy_test_not_done = (@monthly_patients.uniq - @patients_done_pregnancy_test.uniq).uniq
          cohort_struct.pregnancy_test_done_in_first_trimester = @pregnancy_test_done_in_first_trim
          cohort_struct.pregnancy_test_not_done_in_first_trimester = (@patients_done_pregnancy_test - @pregnancy_test_done_in_first_trim).uniq
          cohort_struct.week_of_first_visit_zero_to_twelve = week_of_first_visit_zero_to_twelve(start_date)
          cohort_struct.week_of_first_visit_plus_thirteen = week_of_first_visit_plus_thirteen(start_date)
          cohort_struct.new_hiv_negative_first_visit = @first_new_hiv_negative
          cohort_struct.new_hiv_positive_first_visit = @first_new_hiv_positive
          cohort_struct.prev_hiv_positive_first_visit = @prev_hiv_pos_first_visit
          cohort_struct.pre_hiv_negative_first_visit = @prev_hiv_neg_first_visit
          cohort_struct.not_done_hiv_test_first_visit = @not_done_hiv_test_first_visit
          cohort_struct.total_hiv_positive_first_visit = @total_hiv_positive_first_visit
          cohort_struct.not_on_art_first_visit = @m_not_on_art
          cohort_struct.on_art_before_anc_first_visit = @on_art_before_anc_first_visit
          cohort_struct.start_art_zero_to_twenty_seven_for_first_visit = @start_art_zero_to_twenty_seven_for_first_visit
          cohort_struct.start_art_plus_twenty_eight_for_first_visit = @start_art_plus_twenty_eight_for_first_visit

          # Indicators for the cohort block
          cohort_struct.total_women_in_cohort = @cohort_patients
          @c_pre_hiv_pos = prev_hiv_positive_final_visit
          @c_new_hiv_pos = new_hiv_positive_final_visit - @c_pre_hiv_pos
          @c_total_hiv_positive = (@c_new_hiv_pos + @c_pre_hiv_pos).uniq

          @c_extra_art_checks = extra_art_checks("cohort", c_max_date)
          @c_on_art_in_nart = on_art_in_nart(@c_start_date)
          @c_on_art_before  = (@c_on_art_in_nart["arv_before_visit_one"] - @monthly_patients).uniq
          @on_art_before_anc_final_visit = on_art_before_anc_final_visit
          @start_art_zero_to_twenty_seven_for_final_visit = start_art_zero_to_twenty_seven_for_final_visit
          @start_art_plus_twenty_eight_for_final_visit = start_art_plus_twenty_eight_for_final_visit
          @c_total_on_art = (@on_art_before_anc_final_visit + @start_art_zero_to_twenty_seven_for_final_visit +
            @start_art_plus_twenty_eight_for_final_visit).uniq
          @c_not_on_art = @c_total_hiv_positive - @c_total_on_art

          @on_cpt = @c_on_art_in_nart["on_cpt"]
          @not_on_cpt = (@c_total_hiv_positive - @on_cpt).uniq

          @nvp_given = nvp_given
          @nvp_not_given = @c_total_hiv_positive - @nvp_given

          cohort_struct.patients_with_total_of_one_visit = @anc_visits.reject { |x, y| y != 1 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_two_visits = @anc_visits.reject { |x, y| y != 2 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_three_visits = @anc_visits.reject { |x, y| y != 3 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_four_visits = @anc_visits.reject { |x, y| y != 4 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_five_plus_visits = @anc_visits.reject { |x, y| y < 5 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_pre_eclampsia = patients_with_pre_eclampsia
          cohort_struct.patients_without_pre_eclampsia = @cohort_patients - cohort_struct.patients_with_pre_eclampsia

          # TTV given
          ttv_at_least_3 = patients_given_ttv_at_least_two_doses
          ttv_less_than_2 = patients_given_ttv_less_than_two_doses
          ttv_not_given = @cohort_patients - (ttv_at_least_3 + ttv_less_than_2)
          cohort_struct.patients_given_ttv_less_than_two_doses = ttv_less_than_2 + ttv_not_given
          cohort_struct.patients_given_ttv_at_least_two_doses = ttv_at_least_3

          # SP Doses given
          sp_less_than_3  = patients_given_zero_to_two_sp_doses
          sp_at_least_3   = patients_given_at_least_three_sp_doses
          sp_not_given = (@cohort_patients - (sp_at_least_3 + sp_less_than_3)).uniq
          cohort_struct.patients_given_zero_to_two_sp_doses = sp_less_than_3 + sp_not_given
          cohort_struct.patients_given_at_least_three_sp_doses = sp_at_least_3

          # Fefol tablets given
          fefol_less_than_120, fefol_120_plus = patients_given_fefol_tablets
          cohort_struct.patients_given_less_than_one_twenty_fefol_tablets = fefol_less_than_120
          cohort_struct.patients_given_one_twenty_plus_fefol_tablets = fefol_120_plus

          # Albendazole
          cohort_struct.patients_not_given_albendazole_doses = patients_not_given_albendazole_doses
          cohort_struct.patients_given_one_albendazole_dose = patients_given_one_albendazole_dose

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


          cohort_struct.new_hiv_negative_final_visit = new_hiv_negative_final_visit
          cohort_struct.new_hiv_positive_final_visit = @c_new_hiv_pos
          cohort_struct.prev_hiv_positive_final_visit = @c_pre_hiv_pos
          cohort_struct.pre_hiv_negative_final_visit = pre_hiv_negative_final_visit(start_date)
          cohort_struct.not_done_hiv_test_final_visit = not_done_hiv_test_final_visit(start_date)
          cohort_struct.c_total_hiv_positive = @c_total_hiv_positive
          cohort_struct.not_on_art_final_visit = @c_not_on_art
          cohort_struct.on_art_before_anc_final_visit = @on_art_before_anc_final_visit
          cohort_struct.start_art_zero_to_twenty_seven_for_final_visit = @start_art_zero_to_twenty_seven_for_final_visit
          cohort_struct.start_art_plus_twenty_eight_for_final_visit = @start_art_plus_twenty_eight_for_final_visit
          cohort_struct.not_on_cpt = @not_on_cpt
          cohort_struct.on_cpt = @on_cpt
          cohort_struct.nvp_not_given = @nvp_not_given
          cohort_struct.nvp_given = @nvp_given

          cohort_struct
        end

        # private

        # Get women registered within a specified period
        def registrations(start_dt, end_dt)

          Encounter.joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
            .where(['program_id = ? AND encounter_type = ? AND obs.concept_id = ? AND
              DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? AND encounter.voided = 0',
              PROGRAM.id, CURRENT_PREGNANCY.id, LMP.concept_id, start_dt.to_date,end_dt.to_date])
            .select(['MAX(value_datetime) lmp, patient_id'])
            .group([:patient_id]).collect { |e| e.patient_id }.uniq

        end

        def anc_visits(date)
          @lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{e_date.to_s}', '#{min_date.to_s}')))"

          @monthly_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{@today.to_date.end_of_month}', '#{@today.to_date.beginning_of_month - 10.months}')))"

          lmp = "(SELECT DATE(MAX(o.value_datetime)) FROM obs o WHERE o.person_id = enc.patient_id
                  AND o.concept_id = #{LMP_CONCEPT.concept_id} AND DATE(o.obs_datetime) <= '#{e_date.to_s}'
                  AND DATE(o.obs_datetime) >= '#{min_date.to_s}')"

          @anc_visits = Encounter.find_by_sql(["
            SELECT #{lmp} lmp, enc.patient_id patient_id, MAX(ob.value_numeric)
            form_id FROM encounter enc INNER JOIN obs ob ON ob.encounter_id = enc.encounter_id
            WHERE enc.program_id = ? AND enc.patient_id IN (?) AND enc.encounter_type = ?
            AND ob.concept_id = ? AND DATE(enc.encounter_datetime) <= ?
            AND DATE(enc.encounter_datetime) >= #{lmp}
            GROUP BY enc.patient_id",
            PROGRAM.id, @cohort_patients,
            ANC_VISIT_TYPE_ENCOUNTER.id,
            ConceptName.find_by_name("Reason for visit").concept_id,
            e_date
          ]).collect { |e| [e.patient_id, e.form_id] }

        end

        def pregnancy_test_done(date)
          preg_test = ConceptName.find_by name: "Pregnancy test"

          Encounter.joins(:observations).where("encounter.program_id = ?
            AND encounter.encounter_type = ? AND obs.concept_id = ?
            AND value_coded = ? AND encounter.patient_id in (?)",
            PROGRAM.id, LAB_RESULTS.id, preg_test.concept_id,YES.concept_id,
            @monthly_patients).collect{|e| e.patient_id }.compact.uniq

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
              date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
              date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
              date.to_date, @patients_done_pregnancy_test ]).collect { |e|
              e.patient_id
          }.uniq

        end

        def week_of_first_visit_zero_to_twelve(date)

          Encounter.find_by_sql(["SELECT patient_id, o.value_numeric wk FROM encounter
              INNER JOIN obs o ON o.encounter_id = encounter.encounter_id AND o.concept_id = ?
              AND encounter.voided = 0 WHERE program_id = ? AND patient_id IN (?)
              AND DATE(encounter_datetime) BETWEEN (?) AND (?) GROUP BY patient_id HAVING wk < 13",
              WEEK_OF_FIRST_VISIT.concept_id, PROGRAM.id, @monthly_patients,
              date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
              date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59")
            ]).collect { |e|
              e.patient_id
          }.uniq

        end

        def week_of_first_visit_plus_thirteen(date)

          Encounter.find_by_sql(["SELECT patient_id, o.value_numeric wk FROM encounter
              INNER JOIN obs o ON o.encounter_id = encounter.encounter_id AND o.concept_id = ?
              AND encounter.voided = 0 WHERE program_id = ? AND patient_id IN (?) AND DATE(encounter_datetime)
              BETWEEN (?) AND (?) GROUP BY patient_id HAVING wk > 12",
              WEEK_OF_FIRST_VISIT.concept_id, PROGRAM.id, @monthly_patients,
              date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
              date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59")
            ]).collect { |e|
              e.patient_id
          }.uniq

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

          Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
            WHERE e.program_id = ? AND o.concept_id = ? AND ((o.value_coded = ?)
              OR (o.value_text = 'Positive')) AND e.patient_id IN (?)
            AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
            INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = ?
            WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
            AND DATE(encounter.encounter_datetime) <= ?)
            AND (DATE(e.encounter_datetime) <= ?)
            GROUP BY e.patient_id", PROGRAM.id, HIV_STATUS.concept_id,
            POSITIVE.concept_id,@monthly_patients, HIV_STATUS.concept_id,
            date.to_date.end_of_month,date.to_date.end_of_month
          ]).map(&:patient_id).uniq

        end

        def prev_hiv_positive_first_visit(date)

          Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o ON
                o.encounter_id = e.encounter_id AND e.voided = 0
                WHERE e.program_id = ? AND o.concept_id = ?
                AND ((o.value_coded = ?) OR (o.value_text = 'Negative'))
                AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND
                e.encounter_datetime <= ?", PROGRAM.id, PREV_HIV_TEST.concept_id,
                POSITIVE.concept_id, @monthly_patients,
                date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)
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

        def extra_art_checks(type,date)

          concept_ids = ['Reason for exiting care', 'On ART'].collect{|c| ConceptName.find_by_name(c).concept_id}
          encounter_types = ['LAB RESULTS', 'ART_FOLLOWUP'].collect{|t| EncounterType.find_by_name(t).id}
          art_answers = ['Yes', 'Already on ART at another facility']

          if type === "monthly"

            result = Encounter.find_by_sql(['SELECT e.patient_id FROM encounter e
                      INNER JOIN obs o on o.encounter_id = e.encounter_id
                      WHERE e.voided = 0 AND e.program_id = ? AND e.patient_id IN (?)
                      AND e.encounter_type IN (?) AND o.concept_id IN (?)
                      AND DATE(e.encounter_datetime) <= ? AND COALESCE(
                      (SELECT name FROM concept_name WHERE concept_id = o.value_coded LIMIT 1),
                      o.value_text) IN (?)', PROGRAM.id,
                      ([0] + @monthly_patients), encounter_types, concept_ids, date,
                      art_answers]).map(&:patient_id) rescue []

          elsif

            result = Encounter.find_by_sql(['SELECT e.patient_id FROM encounter e
                      INNER JOIN obs o on o.encounter_id = e.encounter_id
                      WHERE e.voided = 0 AND e.program_id = ? AND e.patient_id IN (?)
                      AND e.encounter_type IN (?) AND o.concept_id IN (?)
                      AND DATE(e.encounter_datetime) <= ? AND COALESCE(
                      (SELECT name FROM concept_name WHERE concept_id = o.value_coded LIMIT 1),
                      o.value_text) IN (?)', PROGRAM.id,
                      ([0] + @cohort_patients), encounter_types, concept_ids, date,
                      art_answers]).map(&:patient_id) rescue []

          end

          return result.uniq

        end

        # Returns patient's ART start date at current facility
        def find_patient_date_enrolled(patient)
          order = Order.joins(:encounter, :drug_order)\
                      .where(encounter: { patient: patient },
                              drug_order: { drug: Drug.arv_drugs })\
                      .order(:start_date)\
                      .first

          order&.start_date&.to_date
        end

        # Returns patient's actual ART start date.
        def find_patient_earliest_start_date(patient, date_enrolled = nil)
          date_enrolled ||= find_patient_date_enrolled(patient)

          patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
          date_enrolled = ActiveRecord::Base.connection.quote(date_enrolled)

          result = ActiveRecord::Base.connection.select_one(
            "SELECT date_antiretrovirals_started(#{patient_id}, #{date_enrolled}) AS date"
          )

          result['date']&.to_date
        end

        def on_art_in_nart(date)

          id_visit_map = []
          anc_visit = {}
          @total_hiv_positive_first_visit.each do |id|
            next if id.nil?

            d = Observation.find_by_sql(['SELECT MAX(value_datetime) as date FROM obs
                    JOIN encounter ON obs.encounter_id = encounter.encounter_id
                    AND encounter.program_id = ? WHERE encounter.encounter_type = ?
                    AND person_id = ? AND concept_id = ?', PROGRAM.id,
                    CURRENT_PREGNANCY.id, id, LMP.concept_id])
                  .first.date.strftime('%Y-%m-%d') #rescue nil

              value = "#{id}|#{d}" unless d.nil?
              id_visit_map << value unless d.nil?
              anc_visit[id] = d unless d.nil?

          end

          result = Hash.new
          @patient_ids = []
          b4_visit_one = []
          no_art = []

          art_patients = ActiveRecord::Base.connection.select_all <<EOF
            SELECT patient_id, earliest_start_date FROM temp_earliest_start_date
            WHERE gender = 'F' AND death_date IS NULL
EOF
          art_patients.each do |patient|
              @patient_ids << patient["patient_id"]
              earliest_start_date = patient["earliest_start_date"].to_date
              result["#{patient["patient_id"]}"] = patient["earliest_start_date"].to_date.strftime("%Y-%m-%d")
              if ((earliest_start_date.to_date < anc_visit[patient["patient_id"]].to_date rescue false))
                b4_visit_one << patient["patient_id"]
              end

          end

          no_art = id_visit_map - result.keys

          dispensing_encounter_type = EncounterType.find_by_name('DISPENSING').id
          cpt_drug_id = Drug.where(["name LIKE ?", "%Cotrimoxazole%"]).map(&:id)

          if @patient_ids.length > 0

            cpt_ids = Encounter.find_by_sql(["SELECT * FROM encounter e
              INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			        WHERE e.encounter_type = (?)
			        AND o.value_drug IN (?) AND e.patient_id IN (?) AND
              e.encounter_datetime <= ?", DISPENSING.id, cpt_drug_id.join(','),
              @patient_ids.join(','),
              date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)

            else

              cpt_ids = []

            end

            result["on_cpt"] = cpt_ids.blank? ? [] : cpt_ids.join(",")

            result["arv_before_visit_one"] = b4_visit_one.blank? ? [] : b4_visit_one #.join(",")

            result["no_art"] = no_art.join(",")

            return result

        end

        def on_art_before_anc_first_visit(date)
          ids =  @m_on_art_before rescue []
          return ( @m_extra_art_checks + ids).uniq
        end

        def start_art_zero_to_twenty_seven_for_first_visit(date)

          remote = []
          obs = Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            AND encounter.voided = 0 AND encounter.program_id = ?
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@m_lmp} AND ?",PROGRAM.id, LMP.concept_id,
            @total_hiv_positive_first_visit, date.to_date.end_of_month]).collect { |ob|
              ident = ob.person_id
              #raise ident.inspect
              if (!ob.value_datetime.blank? && @m_on_art_in_nart["#{ident}"])
                start_date = @m_on_art_in_nart["#{ident}"].to_date
                lmp = ob.value_datetime.to_date
                if  ((start_date >= lmp) && (start_date < (lmp + 28.weeks)))
                  unless remote.include?(ob.person_id)
                  remote << ob.person_id
                end
              end
            end
          }# rescue []

          remote = [] if remote.to_s.blank?

          return (remote - @m_extra_art_checks)

        end

        def start_art_plus_twenty_eight_for_first_visit(date)

          remote = []
          obs = Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            AND encounter.voided = 0 AND encounter.program_id = ?
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@m_lmp} AND ?",PROGRAM.id, LMP.concept_id,
            @total_hiv_positive_first_visit, date.to_date.end_of_month]).collect { |ob|
              ident = ob.person_id
              #raise ident.inspect
              if (!ob.value_datetime.blank? && @m_on_art_in_nart["#{ident}"])
                start_date = @m_on_art_in_nart["#{ident}"].to_date
                lmp = ob.value_datetime.to_date
                if  (start_date >= (lmp + 28.weeks))
                  unless remote.include?(ob.person_id)
                  remote << ob.person_id
                end
              end
            end
          }# rescue []

          remote = [] if remote.to_s.blank?

          return (remote - @m_extra_art_checks)

        end

        def patients_with_pre_eclampsia

            Encounter.joins([:observations])
                .where(["program_id = ? AND concept_id = ? AND value_coded = ? AND DATE(encounter_datetime) "\
                  "BETWEEN (#{@c_lmp}) AND (?) AND encounter.patient_id IN (?)",
                PROGRAM.id, DIAGNOSIS.concept_id, PRE_ECLAMPSIA.concept_id,
                (@c_start_date.to_date + @c_pregnant_range),
                @cohort_patients]).collect { |e| e.patient_id }.uniq
            return []
        end

        def patients_given_ttv_less_than_two_doses
            patients = {}

            Order.joins([[:drug_order => :drug], :encounter])
                .where(["encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= ? "\
                  "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) "\
                  "AND orders.voided = 0", PROGRAM.id, "%TTV%",@c_lmp,
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                  @cohort_patients])
                .group([:patient_id])
                .select(["encounter.patient_id, count(*) encounter_id"]).collect { |o|
                    [o.patient_id, o.encounter_id] }.delete_if { |p, e|
                    v = 0;
                    v = patients[p] if patients[p]
                    v.to_i + e.to_i < 2}.collect { |x, y| x }.uniq
        end

        def patients_given_ttv_at_least_two_doses
            patients = {}

            Order.joins([[:drug_order => :drug], :encounter])
                .where(["encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= ? "\
                  "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) "\
                  "AND orders.voided = 0",PROGRAM.id, "%TTV%",@c_lmp,
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                  @cohort_patients])
                .group([:patient_id])
                .select(["encounter.patient_id, count(*) encounter_id"]).collect { |o|
                    [o.patient_id, o.encounter_id] }.delete_if { |p, e|
                    v = 0;
                    v = patients[p] if patients[p]
                    v.to_i + e.to_i > 1}.collect { |x, y| x }.uniq
        end

        def patients_given_zero_to_two_sp_doses

            Order.where("encounter.program_id = ? AND (drug.name = ? OR drug.name = ?) AND DATE(encounter_datetime) <= ? "\
                  "AND encounter.patient_id IN (?)",
                  "Sulphadoxine and Pyrimenthane (25mg tablet)","SP (3 tablets)",
                  PROGRAM.id,((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
                .joins([[:drug_order => :drug], :encounter])
                .select(["encounter.patient_id, count(encounter.encounter_id) as count, "\
                  "encounter_datetime, drug.name instructions"])
                .group([:patient_id]).collect { |o|
                  [o.patient_id, o.count]
                }.compact.delete_if { |x, y| y.to_i > 2 }.collect { |p, c| p }.uniq
        end

        def patients_given_at_least_three_sp_doses

            Order.where("encounter.program_id = ? AND (drug.name = ? OR drug.name = ?) "\
                  "AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)",
                  PROGRAM.id,"Sulphadoxine and Pyrimenthane (25mg tablet)","SP (3 tablets)",
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
                .joins([[:drug_order => :drug], :encounter])
                .select(["encounter.patient_id, count(encounter.encounter_id) as count, "\
                  "encounter_datetime, drug.name instructions"])
                .group([:patient_id]).collect { |o|
                  [o.patient_id, o.count]
                }.compact.delete_if { |x, y| y.to_i < 3 }.collect { |p, c| p }.uniq
        end

        def patients_given_fefol_tablets
            fefol = {}
            minus_120 = []
            plus_120 = []
            Order.joins([[:drug_order => :drug], :encounter])
              .where(["encounter.program_id = ? AND drug.name = ? AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",PROGRAM.id,
                "Fefol (1 tablet)",((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                @cohort_patients])
              .group([:patient_id]).select(["encounter.patient_id, count(*) datetime,
                drug.name instructions,COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"])
              .each { |o|
                next if ! fefol[o.patient_id].blank?
                fefol[o.patient_id] = o.orderer #if ! fefol[o.patient_id].include?(o.datetime)
              }

            fefol.each{|k, v|
              if v.to_i < 120
                minus_120 << k
              elsif v.to_i >= 120
                plus_120 << k
              end
            }

            return minus_120, plus_120

        end

        def patients_not_given_albendazole_doses

            data = Order.joins([[:drug_order => :drug], :encounter])
                .where(["encounter.program_id = ? AND drug.name REGEXP ? AND (DATE(encounter_datetime) >= #{@c_lmp}
                    AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",PROGRAM.id,
                    "Albendazole", (@c_start_date.to_date + @c_pregnant_range), @cohort_patients])
                .select(["encounter.patient_id, encounter.encounter_id, drug.name instructions,
                    DATEDIFF(orders.auto_expire_date, orders.start_date) orderer"])
                .group("encounter.patient_id")
                .collect { |o|
                  o.patient_id
                }
            results = @cohort_patients - data
        end

        def patients_given_one_albendazole_dose
            result = []

            data = Order.joins([[:drug_order => :drug], :encounter])
                .where(["encounter.program_id = ? AND drug.name LIKE ? AND (DATE(encounter_datetime) >= #{@c_lmp}
                    AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",PROGRAM.id,
                    "%albendazole%", (@c_start_date.to_date + @c_pregnant_range), @cohort_patients])
                .select(["encounter.patient_id, encounter.encounter_id, drug.name instructions,
                    SUM(DATEDIFF(orders.auto_expire_date, orders.start_date)) orderer"])
                .group("encounter.patient_id")
                .collect { |o|
                  [o.patient_id, o.orderer]
                }

            result = data.delete_if { |x, y| y != 1 unless y.blank? }.collect { |p, c| p }

            return result.compact
        end

        def patients_not_given_bed_net
            given_bed_net = patients_given_bed_net
            results = @cohort_patients - given_bed_net
        end

        def patients_given_bed_net

            data = Encounter.joins([:observations])
                .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                  AND (value_text = 'Yes' OR value_coded = ?
                  OR value_text IN ('Given Today', 'Given during previous ANC visit for current pregnancy'))
                  AND ( DATE(encounter_datetime) >= #{@c_lmp} AND DATE(encounter_datetime) <= ?)
                  AND encounter.patient_id IN (?)",PROGRAM.id, CURRENT_PREGNANCY.id,
                  BED_NET.concept_id, YES.concept_id,
                  (@c_start_date.to_date + @c_pregnant_range), @cohort_patients])
                .collect { |e| e.patient_id }.uniq #rescue []

            return data
        end

        def patients_have_hb_less_than_7_g_dl
            Encounter.joins([:observations])
              .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_text < 7 OR value_numeric < 7)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                PROGRAM.id, LAB_RESULTS.id, HB.concept_id,
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                @cohort_patients]).select(["DISTINCT patient_id"]).collect { |e|
                  e.patient_id
                }.uniq
        end

        def  patients_have_hb_greater_than_6_g_dl
            Encounter.joins([:observations])
              .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_text >= 7 OR value_numeric >= 7)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                PROGRAM.id, LAB_RESULTS.id, HB.concept_id,
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                @cohort_patients])
              .select(["DISTINCT patient_id"]).collect { |e|
                e.patient_id
            }.uniq
        end

        def patients_with_negative_syphilis_status
            Encounter.joins([:observations])
              .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_coded = ? OR value_text = ?)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                PROGRAM.id, LAB_RESULTS.id, SYPHILIS.concept_id, NEGATIVE.concept_id,
                "Negative", ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                @cohort_patients])
              .select(["DISTINCT patient_id"]).collect { |e| e.patient_id }
        end

        def patients_with_positive_syphilis_status
            Encounter.joins([:observations])
              .where(["program_id = ? AND encounter_type = ? AND concept_id = ?
                AND (value_coded = ? OR value_text = ?)
                AND (DATE(encounter_datetime) >= #{@c_lmp}
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                PROGRAM.id, LAB_RESULTS.id, SYPHILIS.concept_id, POSITIVE.concept_id,
                "Positive",((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                @cohort_patients])
              .select(["DISTINCT patient_id"]).collect { |e| e.patient_id }
        end

        def new_hiv_negative_final_visit

            querystmnt  = "SELECT e.patient_id, e.encounter_datetime AS date, "
            querystmnt += "(SELECT value_text FROM obs WHERE encounter_id = e.encounter_id "
            querystmnt += "AND obs.concept_id = ?) AS test_date FROM encounter e "
            querystmnt += "INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0 "
            querystmnt += "WHERE o.concept_id = ? AND ((o.value_coded = ?) "
            querystmnt += "OR (o.value_text = 'Negative')) AND e.patient_id IN (?) AND e.program_id = ? "
            querystmnt += "AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter "
            querystmnt += "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = ? "
            querystmnt += "WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id "
            querystmnt += "AND DATE(encounter.encounter_datetime) <= ?) AND (DATE(e.encounter_datetime) <= ?) "
            querystmnt += "GROUP BY e.patient_id HAVING DATE(date) = DATE(test_date)"

            select = Encounter.find_by_sql([querystmnt, HIV_TEST_DATE.concept_id,
                HIV_STATUS.concept_id, NEGATIVE.concept_id, @cohort_patients, PROGRAM.id,
                HIV_STATUS.concept_id, ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day)]).map(&:patient_id)

            return select.uniq
        end

        def new_hiv_positive_final_visit

            querystmnt =  "SELECT e.patient_id, e.encounter_datetime as date FROM encounter e "
            querystmnt += "INNER JOIN obs o ON o.encounter_id = e.encounter_id AND "
            querystmnt += "e.voided = 0 WHERE e.encounter_type = ? AND o.concept_id = ? AND "
            querystmnt += "(o.value_coded = ? OR o.value_text = 'Positive') AND e.patient_id IN (?) AND e.program_id = ? "
            querystmnt += "AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter "
            querystmnt += "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id "
            querystmnt += "AND obs.concept_id = ? WHERE encounter_type = e.encounter_type "
            querystmnt += "AND patient_id = e.patient_id AND DATE(encounter.encounter_datetime) <= ?) "
            querystmnt += "AND (DATE(e.encounter_datetime) <= ?) GROUP BY e.patient_id"

            select = Encounter.find_by_sql([querystmnt,LAB_RESULTS.id,
                HIV_STATUS.concept_id,POSITIVE.concept_id,
                @cohort_patients, PROGRAM.id, HIV_STATUS.concept_id,
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day)]).map(&:patient_id)

            return select.uniq

        end

        def prev_hiv_positive_final_visit

            querystmnt =  "SELECT e.patient_id, e.encounter_datetime as date FROM encounter e "
            querystmnt += "INNER JOIN obs o ON o.encounter_id = e.encounter_id AND "
            querystmnt += "e.voided = 0 WHERE e.encounter_type = ? AND o.concept_id = ? AND "
            querystmnt += "(o.value_coded = ? OR o.value_text = 'Positive') AND e.patient_id IN (?) AND e.program_id = ? "
            querystmnt += "AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter "
            querystmnt += "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id "
            querystmnt += "AND obs.concept_id = ? WHERE encounter_type = e.encounter_type "
            querystmnt += "AND patient_id = e.patient_id AND DATE(encounter.encounter_datetime) <= ?) "
            querystmnt += "AND (DATE(e.encounter_datetime) <= ?) GROUP BY e.patient_id"

            select = Encounter.find_by_sql([querystmnt,LAB_RESULTS.id,
                PREV_HIV_TEST.concept_id,POSITIVE.concept_id,
                @cohort_patients, PROGRAM.id, PREV_HIV_TEST.concept_id,
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day),
                ((@c_start_date.to_date + @c_pregnant_range) - 1.day)]).map(&:patient_id)

            return select.uniq

        end

        def pre_hiv_negative_final_visit(date)
            return []
        end

        def not_done_hiv_test_final_visit(date)
            return []
        end

        #def not_on_art_final_visit(date)
        #    return []
        #end

        def on_art_before_anc_final_visit
          ids =  @c_on_art_before rescue []
          return ( @c_extra_art_checks + ids).uniq
        end

        def start_art_zero_to_twenty_seven_for_final_visit

          remote = []
          obs = Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@c_lmp} AND ?",LMP.concept_id,
            @c_total_hiv_positive, ((@c_start_date.to_date + @c_pregnant_range) - 1.day)])
            .collect { |ob|
              ident = ob.person_id
              #raise ident.inspect
              if (!ob.value_datetime.blank? && @c_on_art_in_nart["#{ident}"])
                start_date = @c_on_art_in_nart["#{ident}"].to_date
                lmp = ob.value_datetime.to_date
                if  ((start_date >= lmp) && (start_date < (lmp + 28.weeks)))
                  unless remote.include?(ob.person_id)
                  remote << ob.person_id
                end
              end
            end
          }# rescue []

          remote = [] if remote.to_s.blank?

          return (remote - @c_extra_art_checks)


        end

        def start_art_plus_twenty_eight_for_final_visit

          remote = []
          obs = Observation.find_by_sql(["SELECT o.value_datetime, o.person_id FROM obs o
            JOIN encounter ON o.encounter_id = encounter.encounter_id
            WHERE o.concept_id = ? AND o.person_id IN (?)
            AND DATE(o.obs_datetime) BETWEEN #{@c_lmp} AND ?",LMP.concept_id,
            @c_total_hiv_positive, ((@c_start_date.to_date + @c_pregnant_range) - 1.day)])
            .collect { |ob|
              ident = ob.person_id
              #raise ident.inspect
              if (!ob.value_datetime.blank? && @c_on_art_in_nart["#{ident}"])
                start_date = @c_on_art_in_nart["#{ident}"].to_date
                lmp = ob.value_datetime.to_date
                if  (start_date >= (lmp + 28.weeks))
                  unless remote.include?(ob.person_id)
                  remote << ob.person_id
                end
              end
            end
          }# rescue []

          remote = [] if remote.to_s.blank?

          return (remote - @c_extra_art_checks)

        end

        def nvp_not_given

            patients_given_nvp = nvp_given
            results = @cohort_patients - patients_given_nvp
            return results

        end

        def nvp_given

            nvp = Order.where(["(drug.name REGEXP ? OR drug.name REGEXP ?)
                            AND (DATE(encounter_datetime) >= #{@c_lmp} AND DATE(encounter_datetime) <= ?)
                            AND encounter.patient_id IN (?)", "NVP", "Nevirapine syrup",
                            (@c_start_date.to_date + @c_pregnant_range),@cohort_patients])
                        .joins([[:drug_order => :drug], :encounter])
                        .select(["encounter.patient_id, count(*) encounter_id, drug.name instructions,
                            SUM(DATEDIFF(auto_expire_date, start_date)) orderer"])
                        .group([:patient_id]).collect { |o| o.patient_id }

            return nvp.uniq rescue []

        end

    end
  end
end
