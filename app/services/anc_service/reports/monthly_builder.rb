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
          monthly_struct
        end
      end
    end
end