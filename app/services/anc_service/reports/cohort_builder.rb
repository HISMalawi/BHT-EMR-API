# frozen_string_literal: true

module ANCService
    module Reports
      class CohortBuilder
        COHORT_LENGTH = 6.months
        LAB_RESULTS =       EncounterType.find_by name: "LAB RESULTS"
        CURRENT_PREGNANCY = EncounterType.find_by name: "CURRENT PREGNANCY"
        ANC_VISIT_TYPE =    EncounterType.find_by name: "ANC VISIT TYPE"

        YES = ConceptName.find_by name: "Yes"
        NO  = ConceptName.find_by name: "No"
        LMP = ConceptName.find_by name: "Date of Last Menstrual Period"
        TTV = ConceptName.find_by name: "TT STATUS"
        WEEK_OF_FIRST_VISIT = ConceptName.find_by name: "Week of first visit"
        REASON_FOR_VISIT =    ConceptName.find_by name: "Reason for visit"
        PREV_HIV_TEST =       ConceptName.find_by name: "Previous HIV Test Results"
        HIV_STATUS    =       ConceptName.find_by name: "HIV Status"
        NEGATIVE =            ConceptName.find_by name: "Negative"
        POSITIVE =            ConceptName.find_by name: "Positive"
        DIAGNOSIS =           ConceptName.find_by name: "DIAGNOSIS"
        PRE_ECLAMPSIA =       ConceptName.find_by name: "PRE-ECLAMPSIA"
        
  
        include ModelUtils
  
        def build(cohort_struct, start_date, end_date)

          # Monthly date ranges
          @m_start_date = start_date
          @m_end_date = end_date

          # Cohort date ranges
          @c_start_date = (start_date.to_date - COHORT_LENGTH)
          @c_end_date = (end_date.to_date - COHORT_LENGTH)
    
          @today = end_date.to_date
          
          @start_date = "#{start_date} 00:00:00"
          @end_date = "#{end_date} 23:59:59"

          @m_pregnant_range = (((@m_end_date.to_time - @m_start_date.to_time).round/(3600*24)) + 1).days
          @c_pregnant_range = 6.months
          
         # @monthly_patients = registrations(start_date.beginning_of_month, start_date.end_of_month)
          #@cohort_patients = total_patients(start_date, 'cohort')

          # women registered in a booking cohort
          @cohort_patients = registrations(@c_start_date.to_date.beginning_of_month, 
                                            @c_end_date.to_date.end_of_month)
      
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
                          "ON ob.encounter_id = enc.encounter_id WHERE enc.patient_id IN (?) "\
                          "AND enc.encounter_type = ? AND ob.concept_id = ? AND "\
                          "DATE(enc.encounter_datetime) <= ? AND DATE(enc.encounter_datetime) >= #{lmp} "\
                          "GROUP BY enc.patient_id"
    
          @anc_visits = Encounter.find_by_sql([visits_query, @cohort_patients,ANC_VISIT_TYPE.id,
                          REASON_FOR_VISIT.concept_id, c_max_date]).collect { |e| 
                          [e.patient_id, e.form_id] 
                        }


          # Indicators for monthly patients in cohort report.
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
          cohort_struct.total_women_in_cohort = @cohort_patients
          cohort_struct.patients_with_total_of_one_visit = @anc_visits.reject { |x, y| y != 1 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_two_visits = @anc_visits.reject { |x, y| y != 2 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_three_visits = @anc_visits.reject { |x, y| y != 3 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_four_visits = @anc_visits.reject { |x, y| y != 4 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_total_of_five_plus_visits = @anc_visits.reject { |x, y| y < 5 }.collect { |x, y| x }.uniq
          cohort_struct.patients_with_pre_eclampsia = patients_with_pre_eclampsia
          cohort_struct.patients_without_pre_eclampsia = @cohort_patients - cohort_struct.patients_with_pre_eclampsia
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

        def anc_visits(date)
            @lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{e_date.to_s}', '#{min_date.to_s}')))"
     
    @monthly_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{@today.to_date.end_of_month}', '#{@today.to_date.beginning_of_month - 10.months}')))"

    lmp = "(SELECT DATE(MAX(o.value_datetime)) FROM obs o WHERE o.person_id = enc.patient_id
            AND o.concept_id = #{LMP_CONCEPT.concept_id} AND DATE(o.obs_datetime) <= '#{e_date.to_s}'
            AND DATE(o.obs_datetime) >= '#{min_date.to_s}')"
    
    @anc_visits = Encounter.find_by_sql(["SELECT #{lmp} lmp, enc.patient_id patient_id, MAX(ob.value_numeric) form_id FROM encounter enc
                                        INNER JOIN obs ob ON ob.encounter_id = enc.encounter_id
                                        WHERE enc.patient_id IN (?) AND enc.encounter_type = ?
                                        AND ob.concept_id = ? AND DATE(enc.encounter_datetime) <= ?
                                        AND DATE(enc.encounter_datetime) >= #{lmp}
                                        GROUP BY enc.patient_id",
        @cohort_patients,
        ANC_VISIT_TYPE_ENCOUNTER.id,
        ConceptName.find_by_name("Reason for visit").concept_id,
        e_date
      ]).collect { |e| [e.patient_id, e.form_id] }
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

        def patients_with_pre_eclampsia
            
            Encounter.joins([:observations])
                .where(["concept_id = ? AND value_coded = ? AND DATE(encounter_datetime) "\
                  "BETWEEN (#{@c_lmp}) AND (?) AND encounter.patient_id IN (?)",
                DIAGNOSIS.concept_id, PRE_ECLAMPSIA.concept_id,
                (@c_start_date.to_date + @c_pregnant_range), 
                @cohort_patients]).collect { |e| e.patient_id }.uniq
            return []
        end

        def patients_given_ttv_less_than_two_doses(date)
            patients = {}
            
            Order.joins([[:drug_order => :drug], :encounter])
                .where(["drug.name LIKE ? AND (DATE(encounter_datetime) >= ? "\
                  "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) "\
                  "AND orders.voided = 0", "%TTV%",@c_lmp, 
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day), 
                  @cohort_patients])
                .group([:patient_id])
                .select(["encounter.patient_id, count(*) encounter_id"]).collect { |o|
                    [o.patient_id, o.encounter_id] }.delete_if { |p, e|
                    v = 0;
                    v = patients[p] if patients[p]
                    v.to_i + e.to_i < 2}.collect { |x, y| x }.uniq
        end
        
        def patients_given_ttv_at_least_two_doses(date)
            patients = {}
            
            Order.joins([[:drug_order => :drug], :encounter])
                .where(["drug.name LIKE ? AND (DATE(encounter_datetime) >= ? "\
                  "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) "\
                  "AND orders.voided = 0", "%TTV%",@c_lmp, 
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day), 
                  @cohort_patients])
                .group([:patient_id])
                .select(["encounter.patient_id, count(*) encounter_id"]).collect { |o|
                    [o.patient_id, o.encounter_id] }.delete_if { |p, e|
                    v = 0;
                    v = patients[p] if patients[p]
                    v.to_i + e.to_i > 1}.collect { |x, y| x }.uniq
        end
        
        def patients_given_zero_to_two_sp_doses(date)
            
            Order.where("(drug.name = ? OR drug.name = ?) AND DATE(encounter_datetime) <= ? "\
                  "AND encounter.patient_id IN (?)",
                  "Sulphadoxine and Pyrimenthane (25mg tablet)","SP (3 tablets)",
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
                .joins([[:drug_order => :drug], :encounter])
                .select(["encounter.patient_id, count(encounter.encounter_id) as count, "\
                  "encounter_datetime, drug.name instructions"])
                .group([:patient_id]).collect { |o|
                  [o.patient_id, o.count]
                }.compact.delete_if { |x, y| y.to_i > 2 }.collect { |p, c| p }.uniq
        end
        
        def patients_given_at_least_three_sp_doses(date)
            
            Order.where("(drug.name = ? OR drug.name = ?) AND DATE(encounter_datetime) <= ? "\
                  "AND encounter.patient_id IN (?)",
                  "Sulphadoxine and Pyrimenthane (25mg tablet)","SP (3 tablets)",
                  ((@c_start_date.to_date + @c_pregnant_range) - 1.day), @cohort_patients)
                .joins([[:drug_order => :drug], :encounter])
                .select(["encounter.patient_id, count(encounter.encounter_id) as count, "\
                  "encounter_datetime, drug.name instructions"])
                .group([:patient_id]).collect { |o|
                  [o.patient_id, o.count]
                }.compact.delete_if { |x, y| y.to_i < 3 }.collect { |p, c| p }.uniq
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
  