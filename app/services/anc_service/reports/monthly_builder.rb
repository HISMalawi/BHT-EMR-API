# frozen_string_literal: true

module ANCService
    module Reports
      class MonthlyBuilder
        COHORT_LENGTH = 6.months
        LAB_RESULTS = EncounterType.find_by name: "LAB RESULTS"
        CURRENT_PREGNANCY = EncounterType.find_by name: "CURRENT PREGNANCY"
        YES = ConceptName.find_by name: "Yes"
        WEEK_OF_FIRST_VISIT = ConceptName.find_by name: "Week of first visit"
        LMP = ConceptName.find_by name: "Date of Last Menstrual Period"
  
        include ModelUtils
  
        def build(monthly_struct, start_date, end_date)

          monthly_struct.total_number_of_anc_visits = total_number_of_anc_visits
          monthly_struct.new_visits = new_visits
          monthly_struct.subsequent_visits = subsequent_visits
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

            return []

        end
        
        def new_visits

            return []

        end
        
        def subsequent_visits

            return []

        end

        def first_trimester
            
            return []
        
        end
        
        def second_trimester
            
            return []
            
        end
        
        def third_trimester
            
            return []
            
        end
        
        def teeneger_pregnancies
            
            return []
            
        end
        
        def women_attending_all_anc_visits
            
            return []
            
        end
        
        def women_screened_for_syphilis
            
            return []
            
        end
        
        def women_checked_hb
            
            return []
            
        end
        
        def women_received_sp_one
            
            return []
            
        end
        
        def women_received_sp_two
            
            return []
            
        end
        
        def women_received_sp_three
            
            return []
            
        end
        
        def women_received_ttv
            
            return []
            
        end
        
        def women_received_one_twenty_iron_tabs
            
            return []
            
        end
        
        def women_received_albendazole
            
            return []
            
        end
        
        def women_received_itn
            
            return []
            
        end
        
        def women_tested_hiv_positive
            
            return []
            
        end
        
        def women_prev_hiv_positive
            
            return []
            
        end
        
        def women_on_cpt
            
            return []
            
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