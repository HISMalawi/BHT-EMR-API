# frozen_string_literal: true

module ARTService
  module Reports
    require 'ostruct'

    class CohortStruct
      FIELD_DESCRIPTIONS = {
        # Table contains various fields of the Cohort report and their descriptions.
        # A fields description is simply "Indicator: Human Readable Name",
        # or "Human Readable Name". The former is for fields with an indicator
        # label and the latter is for fields without.
        # Examples:
        #   ...,
        #   six_a: "KS: Kaposis Sarcoma",
        #   regimen_2p: "Regimen 2P",
        #   ...
        total_other_patients: 'All others (not circled)',
        patients_with_7_plus_doses_missed_at_their_last_visit: 'Adherence: 4+ Doses',
        unknown_age: 'Unknown age',
        cum_unknown_age: 'Unknown Age (Cumulative)',
        quarterly_unknown_age: 'Unknown Age (Quarterly)',
        died_total: 'Died: Died Total',
        died_within_the_1st_month_of_art_initiation: 'M1: Died within the 1st month after ART initiation',
        died_within_the_2nd_month_of_art_initiation: 'M2: Died within the 2nd month of art initiation',
        died_within_the_3rd_month_of_art_initiation: 'M3: Died within the 3rd month after ART initiation',
        died_after_the_3rd_month_of_art_initiation: 'M4+: Died within the 3rd month after ART initiation',
        no_tb: 'Nev/>2 Years: Never TB or TB over 2 years ago',
        cum_no_tb: 'Nev/>2 Years: Never TB or TB over 2 years ago (Cumulative)',
        quarterly_no_tb: 'Nev/>2 Years: Never TB or TB over 2 years ago (Quarterly)',
        who_stage_two: 'CD4: CD4 below threshold',
        cum_who_stage_two: 'CD4: CD4 below threshold (Cumulative)',
        quarterly_who_stage_two: 'CD4: CD4 below threshold (Quarterly)',
        asymptomatic: 'Asy: Asymptomatic / mild',
        cum_asymptomatic: 'Asy: Asymptomatic / mild (Cumulative)',
        quarterly_asymptomatic: 'Asy: Asymptomatic / mild (Quarterly)',
        pregnant_women: 'Preg: Pregnant women',
        cum_pregnant_women: 'Preg: Pregnant Women (Cumulative)',
        quarterly_pregnant_women: 'Preg: Pregnant Women (Quarterly)',
        defaulted: 'Def: Defaulted (more than 2 months overdue after expected to have run out of ARVs',
        tb_within_the_last_two_years: 'Last 2 Years: TB within the last 2 years',
        cum_tb_within_the_last_two_years: 'Last 2 Years: TB within the last 2 years (Cumulative)',
        quarterly_tb_within_the_last_two_years: 'Last 2 Years: TB within the last 2 years (Quarterly)',
        total_patients_without_side_effects: 'Side Effects (as of the last visit before end of quarter)',
        current_episode_of_tb: 'Curr: Current episode of TB',
        cum_current_episode_of_tb: 'Curr: Current episode of TB (Cumulative)',
        quarterly_current_episode_of_tb: 'Curr: Current episode of TB (Quarterly)',
        re_initiated_on_art: 'Re: Patients re-initiated on ART',
        cum_re_initiated_on_art: 'Re: Patients re-initiated on ART (Cumulative)',
        quarterly_re_initiated_on_art: 'Re: Patients re-initiated on ART (Quarterly)',
        zero_p: 'Regimen 0 P',
        one_p: 'Regimen 1 P',
        two_p: 'Regimen 2 P',
        three_p: 'Regimen 3 P',
        four_p: ' Regimen 4 P',
        nine_p: 'Regimen 9 P',
        nine_p_granules: 'Regimen 9P Granules & Pellets',
        nine_p_tabs: 'Regimen 9P Tablets',
        eleven_p: 'Regimen 11 P',
        eleven_p_granules: 'Regimen 11P Granules & Pellets',
        eleven_p_tabs: 'Regimen 11P Tabs',
        zero_a: 'Regimen 0 A',
        one_a: 'Regimen 1 A',
        two_a: 'Regimen 2 A',
        three_a: 'Regimen 3 A',
        four_a: 'Regimen 4 A',
        five_a: 'Regimen 5 A',
        six_a: 'Regimen 6 A',
        seven_a: 'Regimen 7 A',
        eight_a: 'Regimen 8 A',
        nine_a: 'Regimen 9 A',
        ten_a: 'Regimen 10 A',
        eleven_a: 'Regimen 11 A',
        twelve_a: 'Regimen 12 A',
        thirteen_a: 'Regimen 13 A',
        fourteen_p: 'Regimen 14 P',
        fourteen_a: 'Regimen 14 A',
        fifteen_p: 'Regimen 15 P',
        fifteen_a: 'Regimen 15 A',
        sixteen_p: 'Regimen 16 P',
        sixteen_a: 'Regimen 16 A',
        seventeen_p: 'Regimen 17 P',
        seventeen_a: 'Regimen 17 A',
        total_patients_with_side_effects: 'Any side effects',
        total_patients_on_family_planning: 'PIFP: Apprx. % of women who received Depo at ART in the last quarter',
        total_pregnant_women: 'Pregnant/BreastFeeding as of the last visit before end of quarter',
        transfered_out: 'TO: Transferred Out',
        children_12_59_months: 'U5: Children 12 - 59 months',
        cum_children_12_59_months: 'U5: Children 12 - 59 months (Cumulative)',
        quarterly_children_12_59_months: 'U5: Children 12 - 59 months (Quarterly)',
        tb_not_suspected: 'Current TB status any form of TB',
        tb_confirmed_on_tb_treatment: 'TB confirmed, on TB Treatment',
        tb_confirmed_currently_not_yet_on_tb_treatment: 'TB confirmed, not on TB Treatment',
        breastfeeding_mothers: 'BF: Breastfeeding mothers',
        cum_breastfeeding_mothers: 'BF: Breastfeeding mothers (Cumulative)',
        quarterly_breastfeeding_mothers: 'BF: Breastfeeding mothers (Quarterly)',
        patients_with_0_6_doses_missed_at_their_last_visit: 'Adnerence: as of the last visit before end of quarter',
        total_patients_on_arvs_and_ipt: 'IPT: Apprx. % of patients retained in <b>ART</b> who are currently on IPT',
        total_breastfeeding_women: 'Total Breastfeeding Women',
        total_alive_and_on_art: ' Total alive and on ART',
        kaposis_sarcoma: "KS: Kaposi's Sarcoma",
        cum_kaposis_sarcoma: "KS: Kaposi's Sarcoma (Cumulative)",
        quarterly_kaposis_sarcoma: "KS: Kaposi's Sarcoma (Quarterly)",
        unknown_outcome: 'Patient status is unknown',
        unknown_regimen: "Specify above regimens counted as 'Other' Other (paed. / adult)",
        total_patients_with_screened_bp: 'BP screen: Apprx. % of adult ART patients with BP recorded at least once this year',
        cum_total_registered: 'Total Registered (Cummulative)',
        quarterly_total_registered: 'Total Registered (Quarterly)',
        transfer_in: 'TI: Patients transferred in on ART',
        cum_transfer_in: 'TI: Patients transferred in on ART (Cumulative)',
        quarterly_transfer_in: 'TI: Patients transferred in on ART (Quarterly)',
        confirmed_hiv_infection_in_infants_pcr: 'PCR: Infants < 12 months PCR+',
        cum_confirmed_hiv_infection_in_infants_pcr: 'PCR: Infants < 12 months PCR+ (Cumulative)',
        quarterly_confirmed_hiv_infection_in_infants_pcr: 'PCR: Infants < 12 months PCR+ (Quarterly)',
        who_stage_four: '4: WHO stage 4',
        cum_who_stage_four: '4: WHO stage 4 (Cumulative)',
        quarterly_who_stage_four: '4: WHO stage 4 (Quarterly)',
        non_pregnant_females: 'FNP: Non-pregnant females all ages',
        cum_non_pregnant_females: 'FNP: Non-pregnant females all ages (Cumulative)',
        quarterly_non_pregnant_females: 'FNP: Non-pregnant females all ages (Quarterly)',
        unknown_tb_status: 'Unknown (not circled)',
        total_patients_on_arvs_and_cpt: 'CPT: Apprx. % of patients retained in <b>ART</b> who are currently on CPT',
        tb_suspected: 'TB Suspected',
        unknown_side_effects: 'Unkown (not circled)',
        total_registered: 'Total Registered',
        pregnant_females_all_ages: 'Female pregnant_females all ages',
        cum_pregnant_females_all_ages: 'Female pregnant patients all ages (Cumulative)',
        quarterly_pregnant_females_all_ages: 'Cumulative female pregnant patients (Quarterly)',
        patients_with_unknown_adhrence: 'Unknown (not circled)',
        who_stage_three: '3: WHO stage 3',
        cum_who_stage_three: '3: WHO stage 3 (Cumulative)',
        quarterly_who_stage_three: '3: WHO stage 3 (Quarterly)',
        unknown_other_reason_outside_guidelines: 'Unk: Unknown / reason outside guidelines',
        cum_unknown_other_reason_outside_guidelines: 'Unk: Unknown / reason outside guidelines (Cumulative)',
        quarterly_unknown_other_reason_outside_guidelines: 'Unk: Unknown / reason outside guidelines (Quarterly)',
        initiated_on_art_first_time: 'FT: Patients initiated on ART first time',
        cum_initiated_on_art_first_time: 'FT: Patients initiated on ART first time (Cummulative)',
        quarterly_initiated_on_art_first_time: 'FT: Patients initiated on ART first time (Quarterly)',
        presumed_severe_hiv_disease_in_infants: 'PSHD: Pres. Sev. HIV disease age < 12 months',
        cum_presumed_severe_hiv_disease_in_infants: 'PSHD: Pres. Sev. HIV disease age < 12 months (Cumulative)',
        quarterly_presumed_severe_hiv_disease_in_infants: 'PSHD: Pres. Sev. HIV disease age < 12 months (Quarterly)',
        all_males: 'M: Males all ages',
        cum_all_males: 'M: Males all ages (Cumulative)',
        quarterly_all_males: 'M: Males all ages (Quarterly)',
        stopped_art: 'Stop: Stopped taking ARVs (clinician or patient own decision, last known alive)',
        children_below_24_months_at_art_initiation: 'A: Children below 24 months at ART initiation',
        cum_children_below_24_months_at_art_initiation: 'A: Children below 24 months at ART initiation (Cumulative)',
        quarterly_children_below_24_months_at_art_initiation: 'A: Children below 24 m at ART initiation (Quarterly)',
        children_24_months_14_years_at_art_initiation: 'B: Children 24 months - 14 years at ART initiation',
        cum_children_24_months_14_years_at_art_initiation: 'B: Children 24 months - 14 years at ART initiation (Cumulative)',
        quarterly_children_24_months_14_years_at_art_initiation: 'B: Children 24 months - 14 years at ART initiation (Quarterly)',
        adults_at_art_initiation: 'C: Adults 15 years or older at ART initiation',
        cum_adults_at_art_initiation: 'C: Adults 15 years or older at ART initiation (Cumulative)',
        quarterly_adults_at_art_initiation: 'C: Adults 15 years or older at ART initiation (Quarterly)',
        males_initiated_on_art_first_time: 'Newly initiated male patients',
        cum_males_initiated_on_art_first_time: 'Newly initiated male patients (Cummulative)',
        initial_pregnant_females_all_ages: 'Newly initiated pregnant females',
        cum_initial_pregnant_females_all_ages: 'Newly initiated pregnant females (Cummulative)',
        initial_non_pregnant_females_all_ages: 'Newly initiated non-pregnant females',
        cum_initial_non_pregnant_females_all_ages: 'Newly initiated non-pregnant females (Cummulative)',
        unknown_gender: 'All clients registered but has not gender specified',
        cum_unknown_gender: 'All clients registered but has not gender specified (Cummulative)',
        newly_initiated_on_3hp: 'All patients who started 3HP in current reporting period',
        newly_initiated_on_ipt: 'All patients who started IPT in current reporting period'
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

      def respond_to_missing?(name)
        field_name, = split_missing_method_name(name)
        FIELD_DESCRIPTIONS.include?(field_name)
      end

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
