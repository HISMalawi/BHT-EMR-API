# frozen_string_literal: true

module ANCService
    module Reports
      class CohortBuilder
        COHORT_LENGTH = 6.months
        LAB_RESULTS = EncounterType.find_by name: "LAB RESULTS"
        CURRENT_PREGNANCY = EncounterType.find_by name: "CURRENT PREGNANCY"
        YES = ConceptName.find_by name: "Yes"
        NO  = ConceptName.find_by name: "No"
        WEEK_OF_FIRST_VISIT = ConceptName.find_by name: "Week of first visit"
        LMP = ConceptName.find_by name: "Date of Last Menstrual Period"
        PREV_HIV_TEST = ConceptName.find_by name: "Previous HIV Test Results"
        HIV_STATUS    = ConceptName.find_by name: "HIV Status"
        NEGATIVE = ConceptName.find_by name: "Negative"
        POSITIVE = ConceptName.find_by name: "Positive"
  
        include ModelUtils
  
        def build(cohort_struct, start_date, end_date)
          
          # Indicators for monthly patients in cohort report.
          @monthly_patients = registrations(start_date.beginning_of_month, start_date.end_of_month)
          @patients_done_pregnancy_test = pregnancy_test_done(start_date)
          @pregnancy_test_done_in_first_trim = pregnancy_test_done_in_first_trimester(start_date)
          @first_new_hiv_negative = new_hiv_negative_first_visit(start_date)
          @first_new_hiv_positive = new_hiv_positive_first_visit(start_date)
          @prev_hiv_pos_first_visit = prev_hiv_positive_first_visit(start_date)

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
          cohort_struct.pre_hiv_negative_first_visit = pre_hiv_negative_first_visit(start_date)
          cohort_struct.not_done_hiv_test_first_visit = not_done_hiv_test_first_visit(start_date)
          cohort_struct.total_hiv_positive_first_visit = @first_new_hiv_positive + @prev_hiv_pos_first_visit
          cohort_struct.not_on_art_first_visit = not_on_art_first_visit(start_date)
          cohort_struct.on_art_before_anc_first_visit = on_art_before_anc_first_visit(start_date)
          cohort_struct.start_art_zero_to_twenty_seven_for_first_visit = start_art_zero_to_twenty_seven_for_first_visit(start_date)
          cohort_struct.start_art_plus_twenty_eight_for_first_visit = start_art_plus_twenty_eight_for_first_visit(start_date)

          # Indicators for the cohort block
          @cohort_patients = total_patients(start_date, 'cohort')
          cohort_struct.total_women_in_cohort = @cohort_patients
          cohort_struct.patients_with_total_of_one_visit = patients_with_total_of_one_visit(start_date)
          cohort_struct.patients_with_total_of_two_visits = patients_with_total_of_two_visits(start_date)
          cohort_struct.patients_with_total_of_three_visits = patients_with_total_of_three_visits(start_date)
          cohort_struct.patients_with_total_of_four_visits = patients_with_total_of_four_visits(start_date)
          cohort_struct.patients_with_total_of_five_plus_visits = patients_with_total_of_five_plus_visits(start_date)
          cohort_struct.patients_with_pre_eclampsia = patients_with_pre_eclampsia(start_date)
          cohort_struct.patients_without_pre_eclampsia = patients_without_pre_eclampsia(start_date)
          cohort_struct.patients_given_ttv_less_than_two_doses = patients_given_ttv_less_than_two_doses(start_date)
          cohort_struct.patients_given_ttv_at_least_two_doses = patients_given_ttv_at_least_two_doses(start_date)
          cohort_struct.patients_given_zero_to_two_sp_doses = patients_given_zero_to_two_sp_doses(start_date)
          cohort_struct.patients_given_at_least_three_sp_doses = patients_given_at_least_three_sp_doses(start_date)
          cohort_struct.patients_given_less_than_one_twenty_fefol_tablets = patients_given_less_than_one_twenty_fefol_tablets(start_date)
          cohort_struct.patients_given_one_twenty_plus_fefol_tablets = patients_given_one_twenty_plus_fefol_tablets(start_date)
          cohort_struct.patients_not_given_albendazole_doses = patients_not_given_albendazole_doses(start_date)
          cohort_struct.patients_given_one_albendazole_dose = patients_given_one_albendazole_dose(start_date)
          cohort_struct.patients_not_given_bed_net = patients_not_given_bed_net(start_date)
          cohort_struct.patients_given_bed_net = patients_given_bed_net(start_date)
          cohort_struct.patients_have_hb_less_than_7_g_dl = patients_have_hb_less_than_7_g_dl(start_date)
          cohort_struct.patients_have_hb_greater_than_6_g_dl = patients_have_hb_greater_than_6_g_dl(start_date)
          cohort_struct.patients_hb_test_not_done = patients_hb_test_not_done(start_date)
          cohort_struct.patients_with_negative_syphilis_status = patients_with_negative_syphilis_status(start_date)
          cohort_struct.patients_with_positive_syphilis_status = patients_with_positive_syphilis_status(start_date)
          cohort_struct.patients_with_unknown_syphilis_status = patients_with_unknown_syphilis_status(start_date)
          cohort_struct.new_hiv_negative_final_visit = new_hiv_negative_final_visit(start_date)
          cohort_struct.new_hiv_positive_final_visit = new_hiv_positive_final_visit(start_date)
          cohort_struct.prev_hiv_positive_final_visit = prev_hiv_positive_final_visit(start_date)
          cohort_struct.pre_hiv_negative_final_visit = pre_hiv_negative_final_visit(start_date)
          cohort_struct.not_done_hiv_test_final_visit = not_done_hiv_test_final_visit(start_date)
          cohort_struct.not_on_art_final_visit = not_on_art_final_visit(start_date)
          cohort_struct.on_art_before_anc_final_visit = on_art_before_anc_final_visit(start_date)
          cohort_struct.start_art_zero_to_twenty_seven_for_final_visit = start_art_zero_to_twenty_seven_for_final_visit(start_date)
          cohort_struct.start_art_plus_twenty_eight_for_final_visit = start_art_plus_twenty_eight_for_final_visit(start_date)
          cohort_struct
        end
  
        # private

        # Get women registered within a specified period
        def registrations(start_dt, end_dt)
    
          Encounter.joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
            .where(['encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ? 
              AND DATE(encounter_datetime) <= ? AND encounter.voided = 0',
              CURRENT_PREGNANCY.id, LMP.concept_id, start_dt.to_date,end_dt.to_date])
            .select(['MAX(value_datetime) lmp, patient_id'])
            .group([:patient_id]).collect { |e| e.patient_id }.uniq

        end

        def total_patients(date, type)
            anc_program = Program.find_by name: "ANC PROGRAM"

            if (type == 'cohort')
                date = date.to_date - COHORT_LENGTH
            end

            PatientProgram.where("program_id = ? AND date_enrolled BETWEEN DATE(?) AND DATE(?)",
                anc_program.id, date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"), 
                date.end_of_month.strftime("%Y-%m-%d 23:59:59")).order("date_enrolled DESC").collect{|p| 
                    p.patient_id}.compact.uniq
        end
        
        def pregnancy_test_done(date)
            preg_test = ConceptName.find_by name: "Pregnancy test"
            
            Encounter.joins(:observations).where("encounter.encounter_type = ? AND obs.concept_id = ? 
                AND value_coded = ? AND encounter.patient_id in (?)", 
                LAB_RESULTS.id, preg_test.concept_id,YES.concept_id, 
                @monthly_patients).collect{|e| e.patient_id }.compact.uniq
        end

        def pregnancy_test_done_in_first_trimester(date)
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
                encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                AND o.concept_id = ? AND encounter.voided = 0 
                WHERE DATE(encounter_datetime) BETWEEN
                (SELECT DATE(MIN(lmp)) FROM last_menstraul_period_date
                WHERE person_id IN (?) AND obs_datetime BETWEEN ? and ?)
                AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk < 13',
                WEEK_OF_FIRST_VISIT.concept_id,
                @patients_done_pregnancy_test,
                date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                date.to_date, @patients_done_pregnancy_test ]).collect { |e| 
                e.patient_id 
            }.uniq
        end

        def week_of_first_visit_zero_to_twelve(date)
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM encounter
                INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                AND o.concept_id = ? AND encounter.voided = 0
                WHERE DATE(encounter_datetime) BETWEEN
                (select DATE(MIN(lmp)) from last_menstraul_period_date
                where person_id in (?) and obs_datetime between ? and ?)
                AND (?) AND patient_id IN (?)
                GROUP BY patient_id HAVING wk < 13',
                WEEK_OF_FIRST_VISIT.concept_id,
                @monthly_patients,
                date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                date.to_date, @monthly_patients]
            ).collect { |e| e.patient_id }.uniq
        end

        def week_of_first_visit_plus_thirteen(date)
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM encounter
                INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                AND o.concept_id = ? AND encounter.voided = 0
                WHERE DATE(encounter_datetime) BETWEEN
                (select DATE(MIN(lmp)) from last_menstraul_period_date
                where person_id in (?) and obs_datetime between ? and ?)
                AND (?) AND patient_id IN (?)
                GROUP BY patient_id HAVING wk > 12',
                WEEK_OF_FIRST_VISIT.concept_id,
                @monthly_patients,
                date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                date.to_date, @monthly_patients]
            ).collect { |e| e.patient_id }.uniq
        end

        def new_hiv_negative_first_visit(date)
            Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o ON 
                  o.encounter_id = e.encounter_id AND e.voided = 0 
                  WHERE o.concept_id = ? AND ((o.value_coded = ?) OR (o.value_text = 'Negative')) 
                  AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND 
                  e.encounter_datetime <= ?", HIV_STATUS.concept_id, NEGATIVE.concept_id,
                @monthly_patients, date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id).uniq
        end
          
        def new_hiv_positive_first_visit(date)
            Encounter.find_by_sql([
                "SELECT
                        e.patient_id,
                        (select max(encounter_datetime) as date from encounter
                        inner join obs on obs.person_id = encounter.patient_id
                        where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                        AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                        AS date,
                        (SELECT value_datetime FROM obs
                        WHERE encounter_id = e.encounter_id AND obs.concept_id =
                        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                        FROM encounter e
                        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
                        WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
                        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
                        OR (o.value_text = 'Positive'))
                        AND e.patient_id IN (?)
                        AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
                        INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
                        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
                        WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
                        AND DATE(encounter.encounter_datetime) <= ?)
                        AND (DATE(e.encounter_datetime) <= ?)
                        GROUP BY e.patient_id
                        HAVING DATE(date) = DATE(test_date)
                ",CURRENT_PREGNANCY.id,
                LMP.concept_id,
                date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                @monthly_patients,(date.to_date - 1.day), (date.to_date - 1.day)
              ]).map(&:patient_id).uniq
        end

        def prev_hiv_positive_first_visit(date)
            
          Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o ON 
                o.encounter_id = e.encounter_id AND e.voided = 0 
                WHERE o.concept_id = ? AND ((o.value_coded = ?) OR (o.value_text = 'Negative')) 
                AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND 
                e.encounter_datetime <= ?", PREV_HIV_TEST.concept_id, POSITIVE.concept_id,
                @monthly_patients,
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

        def not_done_hiv_test_first_visit(date)
            return []
        end

        def not_on_art_first_visit(date)
            return []
        end

        def on_art_before_anc_first_visit(date)
            return []
        end

        def start_art_zero_to_twenty_seven_for_first_visit(date)
            return []
        end

        def start_art_plus_twenty_eight_for_first_visit(date)
            return []
        end

        def patients_with_total_of_one_visit(date)
            return []
        end

        def patients_with_total_of_two_visits(date)
            return []
        end

        def patients_with_total_of_three_visits(date)
            return []
        end

        def patients_with_total_of_four_visits(date)
            return []
        end

        def patients_with_total_of_five_plus_visits(date)
            return []
        end

        def patients_with_pre_eclampsia(date)
            return []
        end
        
        def patients_without_pre_eclampsia(date)
            return []
        end

        def patients_given_ttv_less_than_two_doses(date)
            return []
        end
        
        def patients_given_ttv_at_least_two_doses(date)
            return []
        end
        
        def patients_given_zero_to_two_sp_doses(date)
            return []
        end
        
        def patients_given_at_least_three_sp_doses(date)
            return []
        end
        
        def patients_given_less_than_one_twenty_fefol_tablets(date)
            return []
        end
        
        def patients_given_one_twenty_plus_fefol_tablets(date)
            return []
        end
        
        def patients_not_given_albendazole_doses(date)
            return []
        end
        
        def patients_given_one_albendazole_dose(date)
            return []
        end
        
        def patients_not_given_bed_net(date)
            return []
        end

        def patients_given_bed_net(date)
            return []
        end

        def patients_have_hb_less_than_7_g_dl(date)
            return []
        end
          
        def  patients_have_hb_greater_than_6_g_dl(date)
            return []
        end

        def patients_hb_test_not_done(date)
            return []
        end

        def patients_with_negative_syphilis_status(date)
            return []
        end

        def patients_with_positive_syphilis_status(date)
            return []
        end
 
        def patients_with_unknown_syphilis_status(date)
            return []
        end

        def new_hiv_negative_final_visit(date)
            return []
        end
          
        def new_hiv_positive_final_visit(date)
            return []
        end
          
        def prev_hiv_positive_final_visit(date)
            return []
        end
          
        def pre_hiv_negative_final_visit(date)
            return []
        end
          
        def not_done_hiv_test_final_visit(date)
            return []
        end
          
        def not_on_art_final_visit(date)
            return []
        end
          
        def on_art_before_anc_final_visit(date)
            return []
        end
          
        def start_art_zero_to_twenty_seven_for_final_visit(date)
            return []
        end
          
        def start_art_plus_twenty_eight_for_final_visit(date)
            return []
        end

    end
  end
end
  