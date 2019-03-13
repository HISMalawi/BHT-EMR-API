# frozen_string_literal: true

module ANCService
    module Reports
      class MonthlyBuilder
        LAB_RESULTS =       EncounterType.find_by name: "LAB RESULTS"
        CURRENT_PREGNANCY = EncounterType.find_by name: "CURRENT PREGNANCY"
        ANC_VISIT_TYPE =    EncounterType.find_by name: "ANC VISIT TYPE"
        DISPENSING =        EncounterType.find_by name: "DISPENSING"

        YES = ConceptName.find_by name: "Yes"
        NO  = ConceptName.find_by name: "No"
        LMP = ConceptName.find_by name: "Date of Last Menstrual Period"
        TTV = ConceptName.find_by name: "TT STATUS"
        HB  = ConceptName.find_by name: "HB TEST RESULT"

        WEEK_OF_FIRST_VISIT = ConceptName.find_by name: "Week of first visit"
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
  
        def build(monthly_struct, start_date, end_date)

          @start_date = start_date.to_date.strftime('%Y-%m-%d 00:00:00')
          @end_date = start_date.end_of_month.to_date.strftime('%Y-%m-%d 23:59:59')

          @total_visits = total_number_of_anc_visits
          @new_monthly_visits = new_visits(@start_date, @end_date)

          monthly_struct.total_number_of_anc_visits = @total_visits
          monthly_struct.new_visits = @new_monthly_visits
          monthly_struct.subsequent_visits = @total_visits - @new_monthly_visits
          monthly_struct.first_trimester = first_trimester
          monthly_struct.second_trimester = second_trimester
          monthly_struct.third_trimester = third_trimester
          monthly_struct.teeneger_pregnancies = teeneger_pregnancies
          monthly_struct.women_attending_all_anc_visits = women_attending_all_anc_visits
          monthly_struct.women_screened_for_syphilis = women_screened_for_syphilis
          monthly_struct.women_checked_hb = women_checked_hb
          monthly_struct.women_received_sp_one = women_received_sp_one
          monthly_struct.women_received_sp_two = women_received_sp_two
          monthly_struct.women_received_sp_three = women_received_sp_three
          monthly_struct.women_received_ttv = women_received_ttv
          monthly_struct.women_received_one_twenty_iron_tabs = women_received_one_twenty_iron_tabs
          monthly_struct.women_received_albendazole = women_received_albendazole
          monthly_struct.women_received_itn = women_received_itn
          monthly_struct.women_tested_hiv_positive = women_tested_hiv_positive
          monthly_struct.women_prev_hiv_positive = women_prev_hiv_positive
          monthly_struct.women_on_cpt = women_on_cpt
          monthly_struct.women_on_art = women_on_art
          monthly_struct.total_number_of_outreach_clinic = total_number_of_outreach_clinic
          monthly_struct.total_number_of_outreach_clinic_attended = total_number_of_outreach_clinic_attended
          monthly_struct
        end

        def total_number_of_anc_visits

            Encounter.joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
                .where(['DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?
                  AND encounter.voided = 0', @start_date, @end_date])
                .group([:patient_id]).collect { |e| e.patient_id }.uniq

        end
        
        def new_visits(start_date, end_date)

                Encounter.joins(['INNER JOIN obs ON obs.person_id = encounter.patient_id'])
                    .where(['encounter_type = ? AND obs.concept_id = ? 
                        AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? 
                        AND encounter.voided = 0',CURRENT_PREGNANCY.id, LMP.concept_id, 
                        start_date, end_date])
                    .select(['MAX(value_datetime) lmp, patient_id'])
                    .group([:patient_id]).collect { |e| e.patient_id }.uniq


        end

        def first_trimester
            
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
                encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                AND o.concept_id = ? AND encounter.voided = 0 
                WHERE DATE(encounter_datetime) BETWEEN
                (select DATE(MIN(lmp)) from last_menstraul_period_date
                where person_id in (?) and obs_datetime between ? and ?)
                AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk < 13',
                    WEEK_OF_FIRST_VISIT.concept_id,
                    @new_monthly_visits, @start_date, @end_date, 
                    @end_date, @new_monthly_visits]).collect { |e| e.patient_id }.uniq
        
        end
        
        def second_trimester
            
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
                encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                AND o.concept_id = ? AND encounter.voided = 0 
                WHERE DATE(encounter_datetime) BETWEEN
                (select DATE(MIN(lmp)) from last_menstraul_period_date
                where person_id in (?) and obs_datetime between ? and ?)
                AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk > 12 AND wk < 27',
                    WEEK_OF_FIRST_VISIT.concept_id, @new_monthly_visits,
                    @start_date, @end_date, @end_date, 
                    @new_monthly_visits]).collect { |e| e.patient_id }.uniq
            
        end
        
        def third_trimester
            
            Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
            encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
            AND o.concept_id = ? AND encounter.voided = 0 
            WHERE DATE(encounter_datetime) BETWEEN
            (select DATE(MIN(lmp)) from last_menstraul_period_date
            where person_id in (?) and obs_datetime between ? and ?)
            AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk > 27',
                WEEK_OF_FIRST_VISIT.concept_id,
                @new_monthly_visits,
                @start_date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                @end_date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                @end_date.to_date, @new_monthly_visits]
            ).collect { |e| e.patient_id }.uniq
            
        end
        
        def teeneger_pregnancies
            
            Person.find_by_sql(["SELECT *, 
                YEAR(date_created) - YEAR(birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(date_created), 
                    '-', MONTH(birthdate), '-', DAY(birthdate)) ,'%Y-%c-%e') > date_created, 1, 0) AS age 
                FROM person WHERE person_id in (?) GROUP BY person_id HAVING age < 20",
                @new_monthly_visits]).collect { |e| e.person_id }
            
        end
        
        def women_attending_all_anc_visits
           
            return []
            
        end
        
        def women_screened_for_syphilis

            Encounter.joins([:observations]).where(["concept_id = ? AND (DATE(encounter_datetime) >= ? " +
                "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                ConceptName.find_by_name("Syphilis Test Result").concept_id,
                @start_date, @end_date, @new_monthly_visits])
              .select(["DISTINCT patient_id"]).collect { |e| e.patient_id }
            
        end
        
        def women_checked_hb

            Encounter.joins([:observations]).where(["concept_id = ? AND (DATE(encounter_datetime) >= ? " +
                "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                ConceptName.find_by_name("HB TEST RESULT").concept_id,
                @start_date, @end_date, @new_monthly_visits])
              .select(["DISTINCT patient_id"]).collect { |e| e.patient_id }
            
        end
        
        def women_received_sp_one
            
            Order.joins([[:drug_order => :drug], :encounter]).where(["(drug.name = ? OR drug.name = ?) " +
                "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?
                AND encounter.patient_id IN (?)", 
                "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                @start_date, @end_date, @new_monthly_visits])
              .group([:patient_id]).select(["encounter.patient_id,
                count(distinct(DATE(encounter_datetime))) encounter_id,
                drug.name instructions"]).collect { |o|
                [o.patient_id, o.encounter_id]
              }.delete_if { |x, y| y.to_i != 1 }.collect { |p, c| p }
            
        end
        
        def women_received_sp_two
            
            Order.joins([[:drug_order => :drug], :encounter]).where(["(drug.name = ? OR drug.name = ?) " +
                "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?
                AND encounter.patient_id IN (?)", 
                "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                @start_date, @end_date, @new_monthly_visits])
              .group([:patient_id]).select(["encounter.patient_id,
                count(distinct(DATE(encounter_datetime))) encounter_id,
                drug.name instructions"]).collect { |o|
                    [o.patient_id, o.encounter_id]
                }.delete_if { |x, y| y.to_i != 2 }.collect { |p, c| p }
            
        end
        
        def women_received_sp_three
            
            Order.joins([[:drug_order => :drug], :encounter]).where(["(drug.name = ? OR drug.name = ?) " +
                "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ?
                AND encounter.patient_id IN (?)", 
                "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                @start_date, @end_date, @new_monthly_visits])
              .group([:patient_id]).select(["encounter.patient_id,
                count(distinct(DATE(encounter_datetime))) encounter_id,
                drug.name instructions"]).collect { |o|
                  [o.patient_id, o.encounter_id]
                }.delete_if { |x, y| y.to_i != 3 }.collect { |p, c| p }
            
        end
        
        def women_received_ttv
            
            patients = {}
            adq_ttv = Encounter.joins([:observations]).where(["concept_id = ? AND (value_numeric = 5
                OR value_text = 5) AND encounter.patient_id IN (?)",
                ConceptName.find_by_name("TT STATUS").concept_id,
                @new_monthly_visits]).select(["patient_id,
                (COALESCE(value_numeric,0)+COALESCE(value_text,0)) form_id"]).collect { |e|
              e.patient_id
            };
        
            rec_ttv = Order.joins([[:drug_order => :drug], :encounter])
                .where(["drug.name LIKE ? AND encounter.patient_id IN (?) 
                    AND orders.voided = 0", "%TTV%", @new_monthly_visits])
                .group([:patient_id]).select(["encounter.patient_id, 
                  count(*) encounter_id"]).collect { |o|
                    o.patient_id
                }
        
            return (adq_ttv + rec_ttv).uniq 
            
        end
        
        def women_received_one_twenty_iron_tabs
            
            fefol = {}
            results = []
            Order.joins([[:drug_order => :drug], :encounter])
                .where(["drug.name = ? AND encounter.patient_id IN (?)",
                    "Fefol (1 tablet)",@new_monthly_visits])
                .group([:patient_id])
                .select(["encounter.patient_id, count(*) datetime, drug.name instructions, 
                    COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"]).each { |o|
                next if ! fefol[o.patient_id].blank?
                fefol[o.patient_id] = o.orderer #if ! fefol[o.patient_id].include?(o.datetime)
            }

            fefol.each{|k, v|
            if v.to_i >= 120
                results << k
            end
            }

            return results
            
        end
        
        def women_received_albendazole
            
            Order.joins([[:drug_order => :drug], :encounter])
                .where(["drug.name REGEXP ? AND encounter.patient_id IN (?)", 
                    "Albendazole",@new_monthly_visits])
                .group([:patient_id]).select(["encounter.patient_id, count(*) encounter_id, 
                    drug.name instructions, SUM(DATEDIFF(auto_expire_date, 
                    start_date)) orderer"]).collect { |o|
                    [o.patient_id, o.orderer]
                }
            
        end
        
        def women_received_itn
            
            Encounter.joins([:observations]).where(["concept_id = ? AND (value_text = 'Yes'
                OR value_coded = ?) AND ( DATE(encounter_datetime) >= ? 
                AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                BED_NET.concept_id, YES.concept_id, @start_date, @end_date, 
                @new_monthly_visits]).collect { |e| 
                    e.patient_id }.uniq rescue []
            
        end
        
        def women_tested_hiv_positive
            
            Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o 
                ON o.encounter_id = e.encounter_id AND e.voided = 0 
                WHERE o.concept_id = ? AND (o.value_coded = ? OR o.value_text = 'Positive') 
                AND e.patient_id IN (?)", HIV_STATUS.concept_id, POSITIVE.concept_id, 
                @new_monthly_visits]).map(&:patient_id)
            
        end
        
        def women_prev_hiv_positive
            
            Encounter.find_by_sql(["SELECT e.patient_id FROM encounter e INNER JOIN obs o 
                ON o.encounter_id = e.encounter_id AND e.voided = 0 
                WHERE o.concept_id = ? AND (o.value_coded = ? OR o.value_text = 'Positive') 
                AND e.patient_id IN (?)", PREV_HIV_TEST.concept_id, 
                POSITIVE.concept_id, @new_monthly_visits]).map(&:patient_id)
            
        end
        
        def women_on_cpt
            
            cpt_drug_id = Drug.where(["name LIKE ?", "%Cotrimoxazole%"]).map(&:id)

            querystmnt  = "SELECT * FROM encounter e INNER JOIN obs o ON e.encounter_id = o.encounter_id "
            querystmnt += "AND e.voided = 0 WHERE e.encounter_type = ? AND o.value_drug IN (?) "
            querystmnt += "AND e.patient_id IN (?) AND e.encounter_datetime <= ?"

            cpt_ids = Encounter.find_by_sql([querystmnt, DISPENSING.id, 
                cpt_drug_id.join(','), @cohort_patients, 
                @end_date]).map(&:patient_id)
            
        end
        
        def women_on_art
            
            return []
            
        end
        
        def total_number_of_outreach_clinic
            
            return []
            
        end
        
        def total_number_of_outreach_clinic_attended
            
            return []
            
        end
        
      end

    end

end