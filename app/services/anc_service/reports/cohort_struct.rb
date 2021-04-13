# frozen_string_literal: true

module ANCService
    module Reports
      require 'ostruct'
  
      class CohortStruct
        FIELD_DESCRIPTIONS = {
          # Table contains various fields of the Cohort report and their descriptions.
          # A fields description is simply "Indicator: Human Readable Name",
          # or "Human Readable Name". The former is for fields with an indicator
          # label and the latter is for fields without.
          
          monthly_patient: "Monthly: New women registered within the reporting month",
          pregnancy_test_done: "Monthly: Patients undergone pregnancy test",
          pregnancy_test_not_done: "Monthly: Patients who did not undergo pregnancy test",
          pregnancy_test_done_in_first_trimester: "Monthly: Patients undergone pregnancy test in the first trimester",
          pregnancy_test_not_done_in_first_trimester: "Monthly: Patients who did not undergo pregnancy test in the first trimester",
          week_of_first_visit_zero_to_twelve: "Monthly: Patients visit in between 0 to 12 weeks of their pregnancy",
          week_of_first_visit_plus_thirteen: "Monthly: Patients visit in between 13 plus weeks of their pregnancy",
          new_hiv_negative_first_visit: "Monthly: New tested negative",
          new_hiv_positive_first_visit: "Monthly: New tested positive",
          prev_hiv_positive_first_visit: "Monthly: Previously tested positive",
          pre_hiv_negative_first_visit: "Monthly: Previously tested negative",
          not_done_hiv_test_first_visit: "Monthly: Patients not undergone HIV test",
          total_hiv_positive_first_visit: "Monthly: Total number of patients with HIV positive",
          not_on_art_first_visit: "Monthly: Patients with HIV positive but not on ART treatment",
          on_art_before_anc_first_visit: "Monthly: Patients with HIV but started ART treatment before ANC visit",
          start_art_zero_to_twenty_seven_for_first_visit: "Monthy: Patients with HIV and started ART treatment between 0-27 weeks",
          start_art_plus_twenty_eight_for_first_visit: "Monthly: Patients with HIV positive and started ART treatment after 27 weeks",

          total_women_in_cohort: "Total women who have visited within the past three months from the reporting month",
          patients_with_total_of_one_visit: "Cohort: Women who have visited ANC once",
          patients_with_total_of_two_visits: "Cohort: Women who have visited ANC twice",
          patients_with_total_of_three_visits: "Cohort: Women who have visited ANC thrice",
          patients_with_total_of_four_visits: "Cohort: Women who have visited ANC four times",
          patients_with_total_of_five_plus_visits: "Cohort: Women who have visited ANC for at least five times",
          patients_with_pre_eclampsia: "Cohort: Patients diagnosized with Pre-Eclampsia",
          patients_without_pre_eclampsia: "Cohort: Patients with no Pre-eclampsia",
          patients_given_ttv_less_than_two_doses: "Cohort: Patients given less tha two ttv doses",
          patients_given_ttv_at_least_two_doses: "Cohort: Patients given at least two ttv doses",
          patients_given_zero_to_two_sp_doses: "Cohort: Patients given less than three sp doses",
          patients_given_at_least_three_sp_doses: "Cohort: Patients given at least three sp doses",
          patients_given_less_than_one_twenty_fefol_tablets: "Cohort: Patients_given less than 120 fefol tablets",
          patients_given_one_twenty_plus_fefol_tablets: "Cohort: Patients given 120+ fefol tablets",
          patients_not_given_albendazole_doses: "Cohort: Patients not given albendazole doses",
          patients_given_one_albendazole_dose: "Cohort: Patients given one albendazole doses",
          patients_not_given_bed_net: "Cohort: Patients not given bed nets",
          patients_given_bed_net: "Cohort: Patients given bed net",
          patients_have_hb_less_than_7_g_dl: "Cohort: Patients with Hb < 7 g/dl",
          patients_have_hb_greater_than_6_g_dl: "Cohort: Patients with Hb >= 7 g/dl",
          patients_hb_test_not_done: "Cohort: Patients Hb test not done",
          patients_with_negative_syphilis_status: "Cohort: Patients with negative syphilis status",
          patients_with_positive_syphilis_status: "Cohort: Patients with positive syphilis status",
          patients_with_unknown_syphilis_status: "Cohort: Patients with Unknown syphilis status",
          new_hiv_negative_final_visit: "Cohort: New tested negative",
          new_hiv_positive_final_visit: "Cohort: New tested positive",
          prev_hiv_positive_final_visit: "Cohort: Previously tested positive",
          pre_hiv_negative_final_visit: "Cohort: Previously tested negative",
          not_done_hiv_test_final_visit: "Cohort: Patients not undergone HIV test",
          c_total_hiv_positive: "Cohort: Total patients with HIV patients",
          not_on_art_final_visit: "Cohort: Patients with HIV positive but not on ART treatment",
          on_art_before_anc_final_visit: "Cohort: Patients with HIV but started ART treatment before ANC visit",
          start_art_zero_to_twenty_seven_for_final_visit: "Cohort: Patients with HIV and started ART treatment between 0-27 weeks",
          start_art_plus_twenty_eight_for_final_visit: "Cohort: Patients with HIV positive and started ART treatment after 27 weeks",
          not_on_cpt: "HIV positive patients on CPT",
          on_cpt: "HIV positive patients not on CPT",
          nvp_not_given: "HIV positive patients not given NVP",
          nvp_given: "HIV positive patients given NVP",
          
        }.freeze
  
        def initialize
          @values = ActiveSupport::HashWithIndifferentAccess.new
        end
  
        def method_missing(name, *args, &block)
          name_prefix, name_suffix = split_missing_method_name(name)
  
          return super(name, *args, &block) unless FIELD_DESCRIPTIONS.include?(name_prefix)
  
          field = value(name_prefix)
          field.contents = args[0] if name_suffix == '='
          field.contents
  
          field.contents
        end
  
        #def respond_to_missing?(name)
        #  field_name, = split_missing_method_name(name)
        #  FIELD_DESCRIPTIONS.include?(field_name)
        #end
  
        def values
          @values.values
        end
  
        private
  
        # Returns a ReportValue object for the given name
        def value(name)
          description = FIELD_DESCRIPTIONS[name]
          iname_parts = description.split(':', 2)
          iname_parts.insert(0, nil) unless iname_parts.size == 2
          short_iname, long_iname = iname_parts
  
          @values[name] ||= OpenStruct.new(
            name: name,
            indicator_name: long_iname.strip,
            indicator_short_name: short_iname ? short_iname.strip : short_iname,
            description: description,
            contents: nil
          )
        end
  
        def split_missing_method_name(name)
          match = name.to_s.match(/^([_A-Z0-9]+)(=)?$/i)
          [match[1].to_sym, match[2]]
        end
      end
    end
  end