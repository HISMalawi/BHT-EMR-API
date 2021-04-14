# frozen_string_literal: true

require_relative './cohort/tpt'

module ARTService
  module Reports
    class CohortBuilder
      QUARTER_LENGTH = 3.months

      include ModelUtils

      def build(cohort_struct, start_date, end_date)
        #load_tmp_patient_table(cohort_struct)
        create_tmp_patient_table
        load_data_into_temp_earliest_start_date(end_date.to_date)

        # create_tmp_patient_table_2(end_date)

        time_started = Time.now.strftime('%Y-%m-%d %H:%M:%S')

        # create_temp_earliest_start_date_table(end_date)
        quarter_start_date = start_date.to_date

        # Get earliest date enrolled
        cum_start_date = get_cum_start_date

        cum_start_date = start_date if cum_start_date.blank?

        # Total registeres
        cohort_struct.total_registered = total_registered(start_date, end_date)
        cohort_struct.cum_total_registered = total_registered(cum_start_date, end_date)
        cohort_struct.quarterly_total_registered = total_registered(quarter_start_date, end_date)

        # Patients initiated on ART first time
        cohort_struct.initiated_on_art_first_time = initiated_on_art_first_time(start_date, end_date)
        cohort_struct.cum_initiated_on_art_first_time = initiated_on_art_first_time(cum_start_date, end_date)
        cohort_struct.quarterly_initiated_on_art_first_time = initiated_on_art_first_time(quarter_start_date, end_date)

        cohort_struct.males_initiated_on_art_first_time = males_initiated_on_art_first_time(start_date, end_date, cohort_struct.initiated_on_art_first_time)
        cohort_struct.cum_males_initiated_on_art_first_time = males_initiated_on_art_first_time(cum_start_date, end_date, cohort_struct.cum_initiated_on_art_first_time)

        # Patients re-initiated on ART
        cohort_struct.re_initiated_on_art = re_initiated_on_art(start_date, end_date)
        cohort_struct.cum_re_initiated_on_art = re_initiated_on_art(cum_start_date, end_date)
        cohort_struct.quarterly_re_initiated_on_art = re_initiated_on_art(quarter_start_date, end_date)

        # Patients transferred in on ART
        cohort_struct.transfer_in = transfer_in(start_date, end_date, cohort_struct.re_initiated_on_art)
        cohort_struct.cum_transfer_in = transfer_in(cum_start_date, end_date, cohort_struct.cum_re_initiated_on_art)
        cohort_struct.quarterly_transfer_in = transfer_in(quarter_start_date, end_date, cohort_struct.quarterly_re_initiated_on_art)

        # All males
        cohort_struct.all_males = males(start_date, end_date)
        cohort_struct.cum_all_males = males(cum_start_date, end_date)
        cohort_struct.quarterly_all_males = males(quarter_start_date, end_date)

        # Pregnant females (all ages)
        cohort_struct.pregnant_females_all_ages = pregnant_females_all_ages(start_date, end_date)
        cohort_struct.cum_pregnant_females_all_ages = pregnant_females_all_ages(cum_start_date, end_date)
        cohort_struct.quarterly_pregnant_females_all_ages = pregnant_females_all_ages(quarter_start_date, end_date)

        cohort_struct.initial_pregnant_females_all_ages = initial_females_all_ages(start_date, end_date, cohort_struct.pregnant_females_all_ages)
        cohort_struct.cum_initial_pregnant_females_all_ages = initial_females_all_ages(cum_start_date, end_date, cohort_struct.cum_pregnant_females_all_ages)



        # Non-pregnant females (all ages)
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having gender of
        # related PERSON entry as F for female and no entries of 'IS PATIENT PREGNANT?' observation answered 'YES'
        # in related HIV CLINIC CONSULTATION encounters not within 28 days from earliest registration date
        cohort_struct.non_pregnant_females = non_pregnant_females(start_date, end_date, cohort_struct.pregnant_females_all_ages)
        cohort_struct.cum_non_pregnant_females = non_pregnant_females(cum_start_date, end_date, cohort_struct.cum_pregnant_females_all_ages)
        cohort_struct.quarterly_non_pregnant_females = non_pregnant_females(quarter_start_date, end_date, cohort_struct.cum_pregnant_females_all_ages)

        cohort_struct.initial_non_pregnant_females_all_ages = initial_females_all_ages(start_date, end_date, cohort_struct.non_pregnant_females.map{|a|a['patient_id']})
        cohort_struct.cum_initial_non_pregnant_females_all_ages = initial_females_all_ages(cum_start_date, end_date, cohort_struct.cum_non_pregnant_females.map{|a|a['patient_id']})


        # Children below 24 months at ART initiation
        cohort_struct.children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(start_date, end_date)
        cohort_struct.cum_children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(cum_start_date, end_date)
        cohort_struct.quarterly_children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(quarter_start_date, end_date)

        # Children 24 months – 14 years at ART initiation
        cohort_struct.children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(start_date, end_date)
        cohort_struct.cum_children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(cum_start_date, end_date)
        cohort_struct.quarterly_children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(quarter_start_date, end_date)

        # Adults at ART initiation
        cohort_struct.adults_at_art_initiation = adults_at_art_initiation(start_date, end_date)
        cohort_struct.cum_adults_at_art_initiation = adults_at_art_initiation(cum_start_date, end_date)
        cohort_struct.quarterly_adults_at_art_initiation = adults_at_art_initiation(quarter_start_date, end_date)

        # Unknown age
        cohort_struct.unknown_age = unknown_age(start_date, end_date)
        cohort_struct.cum_unknown_age = unknown_age(cum_start_date, end_date)
        cohort_struct.quarterly_unknown_age = unknown_age(quarter_start_date, end_date)

        #Unknown gender
        cohort_struct.unknown_gender = unknown_gender(start_date, end_date)
        cohort_struct.cum_unknown_gender = unknown_gender(cum_start_date, end_date)

        # Unique PatientProgram entries at the current location for those
        # patients with at least one state ON ARVs and earliest start date
        # of the 'ON ARVs' state within the quarter and having a
        # REASON FOR ELIGIBILITY observation with an answer as PRESUMED SEVERE HIV
        cohort_struct.presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(start_date, end_date)
        cohort_struct.cum_presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(cum_start_date, end_date)
        cohort_struct.quarterly_presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(quarter_start_date, end_date)

        # Confirmed HIV infection in infants (PCR)

        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and
        # having a REASON FOR ELIGIBILITY observation with an answer as HIV PCR
        cohort_struct.confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(start_date, end_date)
        cohort_struct.cum_confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(cum_start_date, end_date)
        cohort_struct.quarterly_confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(quarter_start_date, end_date)

        # WHO stage 1 or 2, CD4 below threshold
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having a REASON FOR ELIGIBILITY
        # observation with an answer as CD4 COUNT LESS THAN OR EQUAL TO 350 or CD4 COUNT LESS THAN OR EQUAL TO 750
        cohort_struct.who_stage_two = who_stage_two(start_date, end_date)
        cohort_struct.cum_who_stage_two = who_stage_two(cum_start_date, end_date)
        cohort_struct.quarterly_who_stage_two = who_stage_two(quarter_start_date, end_date)

        # Breastfeeding mothers

        # Unique PatientProgram entries at the current location for those patients with at least one state
        # ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as BREASTFEEDING
        cohort_struct.breastfeeding_mothers = breastfeeding_mothers(start_date, end_date)
        cohort_struct.cum_breastfeeding_mothers = breastfeeding_mothers(cum_start_date, end_date)
        cohort_struct.quarterly_breastfeeding_mothers = breastfeeding_mothers(quarter_start_date, end_date)

        # Pregnant women

        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as PATIENT PREGNANT
        cohort_struct.pregnant_women = pregnant_women(start_date, end_date)
        cohort_struct.cum_pregnant_women = pregnant_women(cum_start_date, end_date)
        cohort_struct.quarterly_pregnant_women = pregnant_women(quarter_start_date, end_date)

        # WHO STAGE 3
        # Unique PatientProgram entries at the current location for those patients with at least
        # one state ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as WHO STAGE III
        cohort_struct.who_stage_three = who_stage_three(start_date, end_date)
        cohort_struct.cum_who_stage_three = who_stage_three(cum_start_date, end_date)
        cohort_struct.quarterly_who_stage_three = who_stage_three(quarter_start_date, end_date)

        # WHO STAGE 4
        # Unique PatientProgram entries at the current location for those patients with at least
        # one state ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as WHO STAGE IV
        cohort_struct.who_stage_four = who_stage_four(start_date, end_date)
        cohort_struct.cum_who_stage_four = who_stage_four(cum_start_date, end_date)
        cohort_struct.quarterly_who_stage_four = who_stage_four(quarter_start_date, end_date)

        # Asymptomatic
        # Unique PatientProgram entries at the current location for those patients with at least
        # one state ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as Lymphocytes
        # or LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2

        # For all those patients with WHO stage 1 and 2, only those that were enrolled
        # after or on 2016-04-01 revised_guidelines_start_date = "2016-04-01"
        cohort_struct.asymptomatic = asymptomatic(start_date, end_date)
        cohort_struct.cum_asymptomatic = asymptomatic(cum_start_date, end_date)
        cohort_struct.quarterly_asymptomatic = asymptomatic(quarter_start_date, end_date)

        # Unknown / other reason outside guidelines
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter
        # and having a REASON FOR ELIGIBILITY observation with an answer as UNKNOWN
        cohort_struct.unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(start_date, end_date)
        cohort_struct.cum_unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(cum_start_date, end_date)
        cohort_struct.quarterly_unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(quarter_start_date, end_date)

        # Children 12-23 months

        # Unique PatientProgram entries at the current location for those patients with at least one state
        # ON ARVs and earliest start date of the 'ON ARVs' state within the quarter and having
        # Confirmed HIV Infection (HIV Rapid antibody test or DNA-PCR), regardless of WHO stage and CD4 Count
        cohort_struct.children_12_59_months = children_12_59_months(start_date, end_date)
        cohort_struct.cum_children_12_59_months = children_12_59_months(cum_start_date, end_date)
        cohort_struct.quarterly_children_12_59_months = children_12_59_months(quarter_start_date, end_date)

        # Current EPISODE OF TB

        # Unique PatientProgram entries at the current location for those patients with at least one state
        # ON ARVs and earliest start date of the 'ON ARVs' state within the quarter and having a
        # CURRENT EPISODE OF TB observation at the HIV staging encounter on the initiation date
        cohort_struct.current_episode_of_tb = current_episode_of_tb(start_date, end_date)
        cohort_struct.cum_current_episode_of_tb = current_episode_of_tb(cum_start_date, end_date)
        cohort_struct.quarterly_current_episode_of_tb = current_episode_of_tb(quarter_start_date, end_date)

        # TB within the last 2 years

        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter
        # and having a TB WITHIN THE LAST 2 YEARS observation at the HIV staging encounter on the initiation date
        cohort_struct.tb_within_the_last_two_years = tb_within_the_last_two_years(cohort_struct.current_episode_of_tb, start_date, end_date)
        cohort_struct.cum_tb_within_the_last_two_years = tb_within_the_last_two_years(cohort_struct.cum_current_episode_of_tb, cum_start_date, end_date)
        cohort_struct.quarterly_tb_within_the_last_two_years = tb_within_the_last_two_years(cohort_struct.quarterly_current_episode_of_tb, quarter_start_date, end_date)

        # No TB
        # total_registered - (current_episode - tb_within_the_last_two_years)
        cohort_struct.no_tb = no_tb(cohort_struct.total_registered, cohort_struct.tb_within_the_last_two_years, cohort_struct.current_episode_of_tb)
        cohort_struct.cum_no_tb = cum_no_tb(cohort_struct.cum_total_registered, cohort_struct.cum_tb_within_the_last_two_years, cohort_struct.cum_current_episode_of_tb)
        cohort_struct.quarterly_no_tb = cum_no_tb(cohort_struct.quarterly_total_registered, cohort_struct.quarterly_tb_within_the_last_two_years, cohort_struct.quarterly_current_episode_of_tb)

        # Kaposis Sarcoma
        #
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having a KAPOSIS SARCOMA observation
        # at the HIV staging encounter on the initiation date
        cohort_struct.kaposis_sarcoma = kaposis_sarcoma(start_date, end_date)
        cohort_struct.cum_kaposis_sarcoma = kaposis_sarcoma(cum_start_date, end_date)
        cohort_struct.quarterly_kaposis_sarcoma = kaposis_sarcoma(quarter_start_date, end_date)

        # From this point going down: we update temp_earliest_start_date cum_outcome field to have the latest Cumulative outcome
        update_cum_outcome(end_date)
        update_tb_status(end_date)
        update_patient_side_effects(end_date)

        # Total Alive and On ART
        # Unique PatientProgram entries at the current location for those patients with at least one state
        # ON ARVs and earliest start date of the 'ON ARVs' state less than or equal to end date of quarter
        # and latest state is ON ARVs  (Excluding defaulters)
        cohort_struct.total_alive_and_on_art                      = get_outcome('On antiretrovirals')
        cohort_struct.died_within_the_1st_month_of_art_initiation = died_in('1st month')
        cohort_struct.died_within_the_2nd_month_of_art_initiation = died_in('2nd month')
        cohort_struct.died_within_the_3rd_month_of_art_initiation = died_in('3rd month')
        cohort_struct.died_after_the_3rd_month_of_art_initiation  = died_in('4+ months')
        cohort_struct.died_total                                  = get_outcome('Patient died')
        cohort_struct.defaulted                                   = get_outcome('Defaulted')
        cohort_struct.stopped_art                                 = get_outcome('Treatment stopped')
        cohort_struct.transfered_out                              = get_outcome('Patient transferred out')
        cohort_struct.unknown_outcome                             = get_outcome('Pre-ART (Continue)')

        # ARV Regimen category
        # Alive and On ART and Value Coded of the latest 'Regimen Category' Observation
        # of each patient that is linked to the Dispensing encounter in the reporting period

        prescriptions = cal_regimem_category(cohort_struct.total_alive_and_on_art, end_date)

        concepts = ->(names) { ConceptName.where(name: names).select(:concept_id) }
        drugs = ->(concepts) { Drug.where(concept: concepts).select(:drug_id).collect(&:drug_id) }

        lpv_granules = drugs[concepts[['LPV/r Pellets', 'LPV/r Granules']]]
        lpv_tabs = drugs[concepts['LPV/r']]

        cohort_struct.zero_a            = filter_prescriptions_by_regimen(prescriptions, '0A')
        cohort_struct.one_a             = filter_prescriptions_by_regimen(prescriptions, '1A')
        cohort_struct.zero_p            = filter_prescriptions_by_regimen(prescriptions, '0P')
        cohort_struct.one_p             = filter_prescriptions_by_regimen(prescriptions, '1P')
        cohort_struct.two_a             = filter_prescriptions_by_regimen(prescriptions, '2A')
        cohort_struct.two_p             = filter_prescriptions_by_regimen(prescriptions, '2P')
        cohort_struct.three_a           = filter_prescriptions_by_regimen(prescriptions, '3A')
        cohort_struct.three_p           = filter_prescriptions_by_regimen(prescriptions, '3P')
        cohort_struct.four_a            = filter_prescriptions_by_regimen(prescriptions, '4A')
        cohort_struct.four_p            = filter_prescriptions_by_regimen(prescriptions, '4P')
        cohort_struct.five_a            = filter_prescriptions_by_regimen(prescriptions, '5A')
        cohort_struct.six_a             = filter_prescriptions_by_regimen(prescriptions, '6A')
        cohort_struct.seven_a           = filter_prescriptions_by_regimen(prescriptions, '7A')
        cohort_struct.eight_a           = filter_prescriptions_by_regimen(prescriptions, '8A')
        cohort_struct.nine_a            = filter_prescriptions_by_regimen(prescriptions, '9A')
        cohort_struct.nine_p            = filter_prescriptions_by_regimen(prescriptions, '9P')
        cohort_struct.nine_p_granules   = filter_prescriptions_by_drugs(cohort_struct.nine_p, lpv_granules)
        cohort_struct.nine_p_tabs       = filter_prescriptions_by_drugs(cohort_struct.nine_p, lpv_tabs)
        cohort_struct.ten_a             = filter_prescriptions_by_regimen(prescriptions, '10A')
        cohort_struct.eleven_a          = filter_prescriptions_by_regimen(prescriptions, '11A')
        cohort_struct.eleven_p          = filter_prescriptions_by_regimen(prescriptions, '11P')
        cohort_struct.eleven_p_granules = filter_prescriptions_by_drugs(cohort_struct.eleven_p, lpv_granules)
        cohort_struct.eleven_p_tabs     = filter_prescriptions_by_drugs(cohort_struct.eleven_p, lpv_tabs)
        cohort_struct.twelve_a          = filter_prescriptions_by_regimen(prescriptions, '12A')
        cohort_struct.thirteen_a        = filter_prescriptions_by_regimen(prescriptions, '13A')
        cohort_struct.fourteen_p        = filter_prescriptions_by_regimen(prescriptions, '14P')
        cohort_struct.fourteen_a        = filter_prescriptions_by_regimen(prescriptions, '14A')
        cohort_struct.fifteen_p         = filter_prescriptions_by_regimen(prescriptions, '15P')
        cohort_struct.fifteen_a         = filter_prescriptions_by_regimen(prescriptions, '15A')
        cohort_struct.sixteen_p         = filter_prescriptions_by_regimen(prescriptions, '16P')
        cohort_struct.sixteen_a         = filter_prescriptions_by_regimen(prescriptions, '16A')
        cohort_struct.seventeen_p       = filter_prescriptions_by_regimen(prescriptions, '17P')
        cohort_struct.seventeen_a       = filter_prescriptions_by_regimen(prescriptions, '17A')
        cohort_struct.unknown_regimen   = filter_prescriptions_by_regimen(prescriptions, 'unknown_regimen')

        # Total patients with side effects:
        # Alive and On ART patients with DRUG INDUCED observations during their last HIV CLINIC CONSULTATION encounter up to the reporting period

        with_se, without_se, se_unknowns = patients_side_effects_status(cohort_struct.total_alive_and_on_art, end_date)
        cohort_struct.total_patients_with_side_effects = with_se
        cohort_struct.total_patients_without_side_effects = without_se
        cohort_struct.unknown_side_effects = se_unknowns


        # TB Status
        # Alive and On ART with 'TB Status' observation value of 'TB not Suspected' or 'TB Suspected'
        # or 'TB confirmed and on Treatment', or 'TB confirmed and not on Treatment' or 'Unknown TB status'
        # during their latest HIV Clinic Consultaiton encounter in the reporting period
        write_tb_status_indicators(cohort_struct, cohort_struct.total_alive_and_on_art, start_date, end_date)

        # ART adherence
        #
        # Alive and On ART with value of their 'Drug order adherence" observation during their latest Adherence
        # encounter in the reporting period  between 95 and 105
        adherent, not_adherent, unknown_adherence = latest_art_adherence(cohort_struct.total_alive_and_on_art, start_date, end_date)
        cohort_struct.patients_with_0_6_doses_missed_at_their_last_visit = adherent
        cohort_struct.patients_with_7_plus_doses_missed_at_their_last_visit = not_adherent
        cohort_struct.patients_with_unknown_adhrence = unknown_adherence

        # Pregnant and breastfeeding status during Consultaiton
        cohort_struct.total_pregnant_women = total_pregnant_women(cohort_struct.total_alive_and_on_art, start_date, end_date)
        cohort_struct.total_breastfeeding_women = total_breastfeeding_women(cohort_struct.total_alive_and_on_art, cohort_struct.total_pregnant_women, start_date, end_date)
        cohort_struct.total_other_patients = total_other_patients(cohort_struct.total_alive_and_on_art, cohort_struct.total_breastfeeding_women, cohort_struct.total_pregnant_women)

        # Patients with CPT dispensed at least once before end of quarter and on ARVs
        cohort_struct.total_patients_on_arvs_and_cpt = total_patients_on_arvs_and_cpt(cohort_struct.total_alive_and_on_art, start_date, end_date)

        # Patients with IPT dispensed at least once before end of quarter and on ARVS
        cohort_struct.total_patients_on_arvs_and_ipt = total_patients_on_arvs_and_ipt(cohort_struct.total_alive_and_on_art, start_date, end_date)

        # Patients on family planning methods at least once before end of quarter and on ARVs
        cohort_struct.total_patients_on_family_planning = total_patients_on_family_planning(cohort_struct.total_alive_and_on_art, quarter_start_date, end_date)

        # Patients whose BP was screened and are above 30 years least once before end of quarter and on ARVs
        cohort_struct.total_patients_with_screened_bp = total_patients_with_screened_bp(cohort_struct.total_alive_and_on_art, start_date, end_date)

        # Patients who started TPT in current reporting period
        cohort_struct.newly_initiated_on_3hp = Cohort::Tpt.newly_initiated_on_3hp(start_date, end_date)
        cohort_struct.newly_initiated_on_ipt = Cohort::Tpt.newly_initiated_on_ipt(start_date, end_date)

        puts "Started at: #{time_started}. Finished at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
        cohort_struct
      end

      # private

      def get_disaggregated_cohort(start_date, end_date, gender, ag)
        if ag == '50+ years'
          diff = [50, 1000]
          iu = 'year'
        elsif /years/i.match?(ag)
          diff = ag.sub(' years', '').split('-')
          iu = 'year'
        elsif /months/i.match?(ag)
          diff = ag.sub(' months', '').split('-')
          iu = 'month'
        else
          if gender == 'M'
            diff = [0, 1000]
            iu = 'year'; gender = 'M'
          elsif gender == 'FNP'
            diff = [0, 1000]
            iu = 'year'; gender = 'F'
          elsif gender == 'FP'
            diff = [0, 1000]
            iu = 'year'; gender = 'F'
          elsif gender == 'FBf'
            diff = [0, 1000]
            iu = 'year'; gender = 'F'
          end
        end

        data = ActiveRecord::Base.connection.select_all(
          "SELECT patient_id  FROM temp_earliest_start_date
           WHERE earliest_start_date BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
            AND (earliest_start_date) = (date_enrolled) AND gender = '#{gender.first}'
            AND timestampdiff(#{iu}, birthdate, date_enrolled) BETWEEN #{diff[0].to_i} AND #{diff[1].to_i}"
        )

        data1 = ActiveRecord::Base.connection.select_all(
          "SELECT t1.patient_id FROM temp_earliest_start_date t1
          INNER JOIN temp_patient_outcomes t2 ON t1.patient_id = t2.patient_id
          WHERE date_enrolled <= '#{end_date.to_date}' AND gender = '#{gender.first}'
            AND cum_outcome = 'On antiretrovirals'
            AND timestampdiff(#{iu}, birthdate, date_enrolled) BETWEEN #{diff[0].to_i} AND #{diff[1].to_i}"
        )

        dispensing_encounter_id = EncounterType.find_by_name('DISPENSING').id
        amount_dispensed = concept('Amount dispensed').concept_id
        ipt_drug_ids = Drug.find_all_by_concept_id(656).map(&:drug_id)

        patient_ids = []
        (data1 || {}).each do |x, _y|
          patient_ids << x['patient_id'].to_i
        end

        unless patient_ids.blank?
          data2 = ActiveRecord::Base.connection.select_all(
            "SELECT e.patient_id FROM encounter e
            INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
              AND o.cum_outcome = 'On antiretrovirals' INNER JOIN obs ON obs.encounter_id = e.encounter_id
              AND obs.concept_id = #{amount_dispensed}
            WHERE value_drug IN(#{ipt_drug_ids.join(',')})
              AND e.patient_id IN(#{patient_ids.join(',')})
              AND encounter_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
              AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            GROUP BY e.patient_id"
          )
        end

        [data&.length || 0, data1&.length || 0, data2.length || 0, 0]
      end

      def patient_with_missing_start_reasons(start_date, end_date)
        art_patients = ActiveRecord::Base.connection.select_all(
          "SELECT e.*, patient_reason_for_starting_art_text(e.patient_id) reason
          FROM temp_earliest_start_date e
          WHERE date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'"
        )

        data = {}
        art_patients.each do |p|
          patient = Patient.find(p['patient_id'].to_i)
          reason_for_starting = p['reason']
          next unless reason_for_starting.blank?

          data[patient.patient_id] = {
            arv_number: patient.arv_number,
            earliest_start_date: (begin
                                    p['earliest_start_date'].to_date
                                  rescue StandardError
                                    nil
                                  end),
            date_enrolled: (begin
                              p['date_enrolled'].to_date
                            rescue StandardError
                              nil
                            end),
            name: patient.person.name,
            gender: patient.person.gender,
            birthdate: patient.person.birth_date,
            outcome: p['outcome']
          }
        end

        data
      rescue StandardError
        raise 'Try running the revised cohort before this report'
      end

      def on_art_patients_with_no_arvs_dispensations(start_date, end_date)
        arv_drugs = MedicationService.arv_drugs
        arv_drugs = arv_drugs.map(&:concept_id)

        start_date = start_date.to_date
        end_date = end_date.to_date

        data = ActiveRecord::Base.connection.select_all(
          "SELECT patient_id
          FROM orders o INNER JOIN drug_order drg ON drg.order_id = o.order_id
          AND o.voided = 0
          WHERE drug_inventory_id IN(
            SELECT drug_id FROM drug
            WHERE concept_id IN(#{arv_drugs.join(',')})
          ) GROUP BY patient_id"
        )

        patient_ids = data.map { |d| d['patient_id'].to_i }

        begin
          patients = ActiveRecord::Base.connection.select_all(
            "SELECT * FROM temp_earliest_start_date WHERE patient_id NOT IN(#{patient_ids.join(',')})"
          )
        rescue StandardError
          raise 'Try running the revised cohort before this report'
        end

        reason_for_starting = concept('REASON FOR ART ELIGIBILITY')
        data = {}

        (patients || []).each do |p|
          patient = Patient.find(p['patient_id'].to_i)
          reason_for_starting = PatientService.reason_for_art_eligibility(patient)
          # next unless reason_for_starting.blank?

          patient_obj = PatientService.get_patient(patient.person)
          data[patient_obj.patient_id] = {
            arv_number: patient_obj.arv_number,
            earliest_start_date: p['earliest_start_date'],
            date_enrolled: p['date_enrolled'].to_date,
            name: patient_obj.name,
            gender: patient_obj.sex,
            birthdate: patient_obj.birth_date,
            outcome: p['outcome']
          }
        end

        data
      end

      def patients_with_pre_art_or_unknown_outcome(_start_date, _end_date)
        begin
          patients = ActiveRecord::Base.connection.select_all(
            "SELECT e.*, cum_outcome, patient_reason_for_starting_art_text(e.patient_id) reason_for_starting
            FROM temp_patient_outcomes o
            INNER JOIN temp_earliest_start_date e ON e.patient_id = o.patient_id
            WHERE cum_outcome LIKE '%Pre-%' OR cum_outcome LIKE '%Unknown%'"
          )
        rescue StandardError
          raise 'Try running the revised cohort before this report'
        end

        data = {}

        (patients || []).each do |p|
          patient = Patient.find(p['patient_id'].to_i)

          patient_outcome = p['cum_outcome']
          person = Person.find(p['patient_id'])

          patient_obj = PatientService.get_patient(person)
          data[patient_obj.patient_id] = {
            arv_number: patient_obj.arv_number,
            earliest_start_date: (begin
                                      p['earliest_start_date'].to_date
                                  rescue StandardError
                                    nil
                                    end),
            date_enrolled: (begin
                                p['date_enrolled'].to_date
                            rescue StandardError
                              nil
                              end),
            name: patient_obj.name,
            gender: patient_obj.sex,
            birthdate: patient_obj.birth_date,
            reason_for_starting: p['reason_for_starting'],
            outcome: patient_outcome['outcome']
          }
        end

        data
      end

      STATE_DIED = 3
      STATE_ON_TREATMENT = 7

      def load_data_into_temp_earliest_start_date(end_date)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_earliest_start_date
          SELECT patient_program.patient_id,
                 DATE(MIN(art_order.start_date)) AS date_enrolled,
                 DATE(COALESCE(art_start_date_obs.value_datetime, MIN(art_order.start_date))) AS earliest_start_date,
                 person.birthdate,
                 person.birthdate_estimated,
                 person.death_date,
                 person.gender,
                 IF(person.birthdate IS NOT NULL, TIMESTAMPDIFF(YEAR, person.birthdate,  DATE(COALESCE(art_start_date_obs.value_datetime, MIN(art_order.start_date)))), NULL) AS age_at_initiation,
                 IF(person.birthdate IS NOT NULL, TIMESTAMPDIFF(DAY, person.birthdate,  DATE(COALESCE(art_start_date_obs.value_datetime, MIN(art_order.start_date)))), NULL) AS age_in_days,
                 (SELECT value_coded FROM obs
                  WHERE concept_id = 7563 AND person_id = patient_program.patient_id AND voided = 0
                  ORDER BY obs_datetime DESC LIMIT 1) AS reason_for_starting_art
          FROM patient_program
          INNER JOIN person ON person.person_id = patient_program.patient_id
          LEFT JOIN patient_state AS outcome
            ON outcome.patient_program_id = patient_program.patient_program_id
          LEFT JOIN encounter AS clinic_registration_encounter
            ON clinic_registration_encounter.encounter_type = (
              SELECT encounter_type_id FROM encounter_type WHERE name = 'HIV CLINIC REGISTRATION' LIMIT 1
            )
            AND clinic_registration_encounter.patient_id = patient_program.patient_id
            AND clinic_registration_encounter.voided = 0
          LEFT JOIN obs AS art_start_date_obs
            ON art_start_date_obs.concept_id = 2516
            AND art_start_date_obs.person_id = patient_program.patient_id
            AND art_start_date_obs.voided = 0
            AND art_start_date_obs.obs_datetime < (DATE('#{end_date}') + INTERVAL 1 DAY)
            AND art_start_date_obs.encounter_id = clinic_registration_encounter.encounter_id
          INNER JOIN orders AS art_order
            ON art_order.patient_id = patient_program.patient_id
            AND art_order.voided = 0
            AND art_order.concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)
          INNER JOIN drug_order
            ON drug_order.order_id = art_order.order_id
            AND drug_order.quantity > 0
          WHERE patient_program.voided = 0
            AND outcome.voided = 0
            AND patient_program.program_id = 1
            AND outcome.state = 7
            AND outcome.start_date IS NOT NULL
            AND patient_program.patient_id NOT IN (
              SELECT person_id FROM obs
              WHERE concept_id IN (
                SELECT concept_id FROM concept_name WHERE name LIKE 'Type of patient'
              ) AND value_coded IN (
                SELECT concept_id FROM concept_name WHERE name LIKE 'External Consultation'
              ) AND voided = 0 AND (obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY)
              GROUP BY person_id
            )
          GROUP by patient_program.patient_id
          HAVING date_enrolled <= '#{end_date}'
        SQL
      end

      def create_tmp_patient_table
        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_earliest_start_date')
        ActiveRecord::Base.connection.execute(
          'CREATE TABLE IF NOT EXISTS temp_earliest_start_date (
             patient_id INT PRIMARY KEY,
             date_enrolled DATE,
             earliest_start_date DATE,
             birthdate DATE DEFAULT NULL,
             birthdate_estimated BOOLEAN,
             death_date DATE,
             gender VARCHAR(32),
             age_at_initiation INT DEFAULT NULL,
             age_in_days INT DEFAULT NULL,
             reason_for_starting_art INT DEFAULT NULL
          );'
        )

        ActiveRecord::Base.connection.execute(
          'CREATE INDEX patient_id_index ON temp_earliest_start_date (patient_id)'
        )
        ActiveRecord::Base.connection.execute(
          'CREATE INDEX date_enrolled_index ON temp_earliest_start_date (date_enrolled)'
        )

        ActiveRecord::Base.connection.execute(
          'CREATE INDEX patient_id__date_enrolled_index ON temp_earliest_start_date (patient_id, date_enrolled)'
        )

        ActiveRecord::Base.connection.execute(
          'CREATE INDEX earliest_start_date_index ON temp_earliest_start_date (earliest_start_date)'
        )
        ActiveRecord::Base.connection.execute(
          'CREATE INDEX earliest_start_date__date_enrolled_index ON temp_earliest_start_date (patient_id, earliest_start_date, date_enrolled, gender)'
        )
        ActiveRecord::Base.connection.execute(
          'CREATE INDEX idx_reason_for_art ON temp_earliest_start_date (reason_for_starting_art)'
        )
      end

      def update_cum_outcome(end_date)
        Cohort::Outcomes.update_cummulative_outcomes(end_date)
      end

      def update_tb_status(end_date)
        ActiveRecord::Base.connection.execute(
          'DROP TABLE IF EXISTS `temp_patient_tb_status`'
        )

        ActiveRecord::Base.connection.execute <<~SQL
        CREATE TABLE temp_patient_tb_status (
          patient_id INT(11) PRIMARY KEY,
          tb_status INT(11)
        )
        SQL

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_tb_status
           ADD INDEX patient_id_index (patient_id)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_tb_status
           ADD INDEX tb_status_index (tb_status)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_tb_status
           ADD INDEX patient_id_tb_status_index (patient_id, tb_status)'
        )

        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_patient_tb_status
            SELECT e.patient_id, obs.value_coded
            FROM temp_earliest_start_date e
            INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
            RIGHT JOIN obs ON obs.person_id = o.patient_id
            WHERE e.date_enrolled <= '#{end_date}' AND obs.obs_datetime <= '#{end_date} 23:59:59'
            AND cum_outcome = 'On antiretrovirals' AND obs.voided = 0
            AND obs.concept_id = 7459
            AND obs.obs_datetime = (
              SELECT MAX(t.obs_datetime) FROM obs t WHERE t.concept_id = 7459 AND t.voided = 0
              AND t.person_id = e.patient_id AND t.obs_datetime <= '#{end_date} 23:59:59'
            ) GROUP BY e.patient_id;
        SQL

      end

      def update_patient_side_effects(end_date)
        Cohort::SideEffects.update_side_effects(end_date)
      end

      private

      def total_patients_with_screened_bp(total_alive_and_on_art, _start_date, end_date)
        return 0 if total_alive_and_on_art.empty?

        bp_concepts = ConceptName.where(name: ['Systolic blood pressure', 'Diastolic blood pressure'])
                                 .select(:concept_id)

        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.person_id
          FROM obs o
          INNER JOIN (
            SELECT person_id, MAX(obs.obs_datetime) AS obs_datetime
            FROM obs
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = obs.person_id
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            WHERE voided = 0
              AND concept_id IN (#{bp_concepts.to_sql})
              AND value_text IS NOT NULL
              AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            GROUP BY person_id
          ) AS max_obs
            ON max_obs.person_id = o.person_id
            AND max_obs.obs_datetime = o.obs_datetime
          INNER JOIN temp_patient_outcomes
            ON temp_patient_outcomes.patient_id = o.person_id
            AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
          WHERE o.voided = 0
            AND o.concept_id in (#{bp_concepts.to_sql})
            AND o.value_text IS NOT NULL
          GROUP BY o.person_id;
        SQL

        ((results.count.to_f / total_alive_and_on_art.count) * 100).to_i
      end

      def total_patients_on_family_planning(patients_list, start_date, end_date)
        patient_ids = []; patient_list = []

        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        result = []

        all_women = ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE (gender = 'F' OR gender = 'Female') AND patient_id IN  (#{patient_ids.join(',')})
          AND date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
          GROUP BY patient_id"
        )

        (all_women || []).each do |patient|
          patient_list << patient['patient_id'].to_i
        end

        return 0 if patient_list.blank?

        hiv_clinic_consultation_encounter_type_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').encounter_type_id
        method_of_family_planning_concept_id = concept('Method of family planning').concept_id
        family_planning_action_to_take_concept_id = concept('Family planning, action to take').concept_id
        none_concept_id = [concept('None').concept_id, concept('No').concept_id]

        results = ActiveRecord::Base.connection.select_all(
          "SELECT o.person_id
          FROM obs o
          inner join encounter e on e.encounter_id = o.encounter_id AND e.encounter_type = #{hiv_clinic_consultation_encounter_type_id}
          WHERE o.voided = 0 AND e.voided = 0
          AND (o.concept_id IN (#{family_planning_action_to_take_concept_id}, #{method_of_family_planning_concept_id}) AND o.value_coded NOT IN (#{none_concept_id.join(',')}))
          AND o.person_id IN (#{patient_list.join(',')})
          AND o.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND DATE(o.obs_datetime) = (SELECT max(date(obs.obs_datetime)) FROM obs obs
            WHERE obs.voided = 0
            AND (obs.concept_id IN (#{family_planning_action_to_take_concept_id}, #{method_of_family_planning_concept_id}))
            AND obs.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND obs.person_id = o.person_id)
          GROUP BY o.person_id"
        )

        total_percent = begin
                         ((results.count.to_f / patient_list.count.to_f) * 100).to_i
                        rescue StandardError
                          0
                       end
        total_percent
      end

      def total_patients_on_arvs_and_ipt(patients_list, start_date, end_date)
        isoniazid_concept_id = concept('Isoniazid').concept_id
        pyridoxine_concept_id = concept('Pyridoxine').concept_id

        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        results = ActiveRecord::Base.connection.select_all(
          "SELECT ods.patient_id FROM orders ods
          INNER JOIN drug_order dos ON ods.order_id = dos.order_id AND ods.voided = 0
          WHERE ods.concept_id IN (#{isoniazid_concept_id}, #{pyridoxine_concept_id})
          AND dos.quantity IS NOT NULL
          AND ods.patient_id in (#{patient_ids.join(',')})
          AND ods.start_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND DATE(ods.start_date) = (SELECT MAX(DATE(o.start_date)) FROM orders o
                                      INNER JOIN drug_order d ON o.order_id = d.order_id AND o.voided = 0
                                      WHERE o.concept_id IN (#{isoniazid_concept_id}, #{pyridoxine_concept_id})
                                      AND o.patient_id = ods.patient_id
                                      AND d.quantity IS NOT NULL
                                      AND o.start_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                                      AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY ods.patient_id"
        )

        total_percent = ((results.count.to_f / patient_ids.count.to_f) * 100).to_i
        total_percent
      end

      def total_patients_on_arvs_and_cpt(patients_list, start_date, end_date)
        cpt_concept_id = concept('Cotrimoxazole').concept_id

        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        results = ActiveRecord::Base.connection.select_all(
          "SELECT ods.patient_id FROM orders ods
          INNER JOIN drug_order dos ON ods.order_id = dos.order_id AND ods.voided = 0
          WHERE ods.concept_id = #{cpt_concept_id}
          AND dos.quantity IS NOT NULL
          AND ods.patient_id in (#{patient_ids.join(',')})
          AND ods.start_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND DATE(ods.start_date) = (SELECT MAX(DATE(o.start_date)) FROM orders o
                                      INNER JOIN drug_order d ON o.order_id = d.order_id AND o.voided = 0
                                      WHERE o.concept_id =  #{cpt_concept_id}
                                      AND d.quantity IS NOT NULL
                                      AND o.patient_id = ods.patient_id
                                      AND o.start_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
                                      AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')

          GROUP BY ods.patient_id"
        )

        total_percent = ((results.count.to_f / patient_ids.count.to_f) * 100).to_i
        total_percent
      end

      def total_breastfeeding_women(_patients_list, total_pregnant_women, _start_date, end_date)
        total_pregnant_women = if total_pregnant_women.empty?
                                 [0]
                               else
                                 total_pregnant_women.map { |woman| woman['person_id'].to_i }
                               end


        encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                       .select(:encounter_type_id)

        breastfeeding_concepts = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                            .select(:concept_id)

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT obs.person_id, obs.value_coded
          FROM obs
          INNER JOIN encounter enc
            ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0
            AND enc.encounter_type IN (#{encounter_types.to_sql})
          INNER JOIN temp_earliest_start_date e
            ON e.patient_id = enc.patient_id
            AND LEFT(e.gender, 1) = 'F'
          INNER JOIN temp_patient_outcomes
            ON temp_patient_outcomes.patient_id = e.patient_id
            AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
          INNER JOIN (
            SELECT person_id, MAX(obs_datetime) AS obs_datetime
            FROM obs
            INNER JOIN encounter
              ON encounter.encounter_id = obs.encounter_id
              AND encounter.encounter_type IN (#{encounter_types.to_sql})
              AND encounter.voided = 0
            WHERE person_id IN (SELECT patient_id FROM temp_patient_outcomes WHERE cum_outcome = 'On antiretrovirals')
              AND concept_id IN (#{breastfeeding_concepts.to_sql})
              AND obs.voided = 0
              AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            GROUP BY person_id
          ) AS max_obs
            ON max_obs.person_id = obs.person_id
            AND max_obs.obs_datetime = obs.obs_datetime
          WHERE obs.person_id = e.patient_id
            AND obs.person_id NOT IN (#{total_pregnant_women.join(',')})
            AND obs.obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            AND obs.concept_id IN (#{breastfeeding_concepts.to_sql})
            AND obs.voided = 0
          GROUP BY obs.person_id
          HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;
        SQL
      end

      def total_pregnant_women(_patients_list, _start_date, end_date)
        encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                       .select(:encounter_type_id)

        pregnant_concepts = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                       .select(:concept_id)

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT obs.person_id, obs.value_coded FROM obs obs
            INNER JOIN encounter enc
              ON enc.encounter_id = obs.encounter_id
              AND enc.voided = 0
              AND enc.encounter_type IN (#{encounter_types.to_sql})
            INNER JOIN temp_earliest_start_date e
              ON e.patient_id = enc.patient_id
              AND LEFT(e.gender, 1) = 'F'
          INNER JOIN temp_patient_outcomes
            ON temp_patient_outcomes.patient_id = e.patient_id
            AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
          INNER JOIN (
            SELECT person_id, MAX(obs_datetime) AS obs_datetime
            FROM obs
            INNER JOIN encounter
              ON encounter.encounter_id = obs.encounter_id
              AND encounter.encounter_type IN (#{encounter_types.to_sql})
              AND encounter.voided = 0
            WHERE concept_id IN (#{pregnant_concepts.to_sql})
              AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
              AND obs.voided = 0
            GROUP BY person_id
          ) AS max_obs
            ON max_obs.person_id = obs.person_id
            AND max_obs.obs_datetime = obs.obs_datetime
          WHERE obs.concept_id IN (#{pregnant_concepts.to_sql})
            AND obs.voided = 0
          GROUP BY obs.person_id
          HAVING value_coded = 1065
          ORDER BY obs.obs_datetime DESC;
        SQL
      end

      def total_other_patients(patient_list, all_breastfeeding_women, all_pregnant_women)
        patient_ids = []; all_pregnant_women_ids = []; all_breastfeeding_women_ids = []

        (patient_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        (all_pregnant_women || []).each do |row|
          all_pregnant_women_ids << row['person_id'].to_i
        end

        (all_breastfeeding_women || []).each do |row|
          all_breastfeeding_women_ids << row['person_id'].to_i
        end

        results = (patient_ids - (all_breastfeeding_women_ids + all_pregnant_women_ids))
        results
      end

      MIN_ART_ADHERENCE_THRESHOLD = 95.0 # Those below are not adherent
      MAX_ART_ADHERENCE_THRESHOLD = 105.0 # Thoseabove are not adherent

      # Groups patients list into three groups based on the adherence rates
      #
      # Returns: A list of 3 lists as follows:
      #    [
      #       [adherent patients],
      #       [inadherent patients],
      #       [patients whose adherence rate is unknown]
      #    ]
      def latest_art_adherence(patients_alive_and_on_art, start_date, end_date)
        patients_alive_and_on_art = Set.new(patients_alive_and_on_art.map { |patient| patient['patient_id'] })
        end_date = ActiveRecord::Base.connection.quote(end_date)

        not_adherent = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT adherence.person_id
          FROM obs AS adherence
          INNER JOIN (
            SELECT obs.person_id, DATE(MAX(obs.obs_datetime)) AS visit_date
            FROM obs
            INNER JOIN orders
              ON orders.order_id = obs.order_id
              AND orders.concept_id IN (#{arv_drug_concepts.to_sql})
              AND orders.order_type_id = #{drug_order_type.order_type_id}
              AND orders.voided = 0
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = obs.person_id
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            WHERE obs.concept_id = #{drug_order_adherence_concept.concept_id}
              AND obs.obs_datetime < (DATE(#{end_date}) + INTERVAL 1 DAY)
              AND (obs.value_numeric IS NOT NULL OR obs.value_text IS NOT NULL)
              AND obs.voided = 0
            GROUP BY obs.person_id
          ) AS max_adherence
            ON max_adherence.person_id = adherence.person_id
            AND adherence.obs_datetime >= max_adherence.visit_date
            AND adherence.obs_datetime < (max_adherence.visit_date + INTERVAL 1 DAY)
          INNER JOIN orders
            ON orders.order_id = adherence.order_id
            AND orders.order_type_id = #{drug_order_type.order_type_id}
            AND orders.concept_id IN (#{arv_drug_concepts.to_sql})
            AND orders.voided = 0
          WHERE adherence.concept_id = #{drug_order_adherence_concept.concept_id}
            AND ((adherence.value_numeric < #{MIN_ART_ADHERENCE_THRESHOLD}
                  OR adherence.value_numeric > #{MAX_ART_ADHERENCE_THRESHOLD})
                 OR (CAST(adherence.value_text AS SIGNED INTEGER) < #{MIN_ART_ADHERENCE_THRESHOLD}
                     OR CAST(adherence.value_text AS SIGNED INTEGER) > #{MAX_ART_ADHERENCE_THRESHOLD}))
            AND adherence.voided = 0
          GROUP BY adherence.person_id
        SQL

        not_adherent = not_adherent.empty? ? [] : not_adherent.map { |row| row['person_id'] }

        adherent = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT adherence.person_id
          FROM obs AS adherence
          INNER JOIN (
            SELECT obs.person_id, DATE(MAX(obs.obs_datetime)) AS visit_date
            FROM obs
            INNER JOIN orders
              ON orders.order_id = obs.order_id
              AND orders.concept_id IN (#{arv_drug_concepts.to_sql})
              AND orders.order_type_id = #{drug_order_type.order_type_id}
              AND orders.voided = 0
            INNER JOIN temp_patient_outcomes
              ON temp_patient_outcomes.patient_id = obs.person_id
              AND temp_patient_outcomes.patient_id NOT IN (#{(not_adherent.blank? ? 0 : not_adherent.join(','))})
              AND temp_patient_outcomes.cum_outcome = 'On antiretrovirals'
            WHERE obs.concept_id = #{drug_order_adherence_concept.concept_id}
              AND obs.obs_datetime < (DATE(#{end_date}) + INTERVAL 1 DAY)
              AND (obs.value_numeric IS NOT NULL OR obs.value_text IS NOT NULL)
              AND obs.voided = 0
            GROUP BY obs.person_id
          ) AS max_adherence
            ON max_adherence.person_id = adherence.person_id
            AND adherence.obs_datetime >= max_adherence.visit_date
            AND adherence.obs_datetime < (max_adherence.visit_date + INTERVAL 1 DAY)
          INNER JOIN orders
            ON orders.order_id = adherence.order_id
            AND orders.order_type_id = #{drug_order_type.order_type_id}
            AND orders.concept_id IN (#{arv_drug_concepts.to_sql})
            AND orders.voided = 0
          WHERE adherence.concept_id = #{drug_order_adherence_concept.concept_id}
            AND ((adherence.value_numeric >= #{MIN_ART_ADHERENCE_THRESHOLD}
                  OR adherence.value_numeric <= #{MAX_ART_ADHERENCE_THRESHOLD})
                 OR (CAST(adherence.value_text AS SIGNED INTEGER) >= #{MIN_ART_ADHERENCE_THRESHOLD}
                     OR CAST(adherence.value_text AS SIGNED INTEGER) <= #{MAX_ART_ADHERENCE_THRESHOLD}))
            AND adherence.voided = 0
          GROUP BY adherence.person_id
        SQL

        adherent = adherent.map { |row| row['person_id'] }
        unknown_adherence = Set.new(patients_alive_and_on_art) - adherent - not_adherent

        [adherent, not_adherent, unknown_adherence]
      end

      def adherence_encounter
        @adherence_encounter ||= encounter_type('ART ADHERENCE')
      end

      def hiv_program
        @hiv_program ||= program('HIV PROGRAM')
      end

      def drug_order_adherence_concept
        @drug_order_adherence_concept ||= concept('Drug order adherence')
      end

      def drug_order_type
        @drug_order_type ||= OrderType.find_by_name('Drug order')
      end

      def arv_drug_concepts
        @arv_drug_concepts ||= ConceptSet.where(set: concept('Antiretroviral drugs'))
                                         .select(:concept_id)
      end

      def write_tb_status_indicators(cohort_struct, patients_alive_and_on_art, start_date, end_date)
        cohort_struct.tb_suspected = []
        cohort_struct.tb_not_suspected = []
        cohort_struct.tb_confirmed_on_tb_treatment = []
        cohort_struct.tb_confirmed_currently_not_yet_on_tb_treatment = []
        cohort_struct.unknown_tb_status = []

        tb_suspected_concept = concept('TB Suspected')
        tb_not_suspected_concept = concept('TB Not Suspected')
        tb_confirmed_but_not_on_treatment = concept('Confirmed TB NOT on Treatment')
        tb_confirmed_and_on_treatment = concept('Confirmed TB on Treatment')

        #patients_alive_and_on_art
        (all_tb_statuses(end_date) || []).each do |data|
          tb_status_value = data['tb_status'].to_i rescue nil

          case tb_status_value
            when tb_suspected_concept.concept_id
              cohort_struct.tb_suspected << data['patient_id']
            when tb_not_suspected_concept.concept_id
              cohort_struct.tb_not_suspected << data['patient_id']
            when tb_confirmed_and_on_treatment.concept_id
              cohort_struct.tb_confirmed_on_tb_treatment << data['patient_id']
            when tb_confirmed_but_not_on_treatment.concept_id
              cohort_struct.tb_confirmed_currently_not_yet_on_tb_treatment << data['patient_id']
            else
              cohort_struct.unknown_tb_status << data['patient_id']
          end
        end
      end

      def all_tb_statuses(end_date)
        ActiveRecord::Base.connection.select_all("
          SELECT e.*, tb_status FROM temp_earliest_start_date e
          LEFT JOIN temp_patient_tb_status s ON s.patient_id = e.patient_id
          INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
          WHERE o.cum_outcome = 'On antiretrovirals'
          AND DATE(e.date_enrolled) <= '#{end_date.to_date}';
        ")
      end

      def get_tb_status(tb_status)
        registered = []
        (@tb_status || []).each do |status|
          if tb_status == status[:tb_status]
            registered << { patient_id: status[:patient_id], tb_status: status[:tb_status] }
          end
        end

        registered
      end

      def patients_side_effects_status(patients_alive_and_on_art, end_date)
        with_side_effects = []
        without_side_effects = []
        unknowns = []

        records = ActiveRecord::Base.connection.select_all <<EOF
        SELECT e.*, s.has_se FROM temp_earliest_start_date e
        INNER JOIN temp_patient_side_effects s ON s.patient_id = e.patient_id
        INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
        WHERE o.cum_outcome = 'On antiretrovirals'
        AND DATE(e.date_enrolled) <= '#{end_date.to_date}';
EOF

        (records || []).each do |data|
          if data['has_se'] == 'Yes'
            with_side_effects << data['patient_id']
          elsif data['has_se'] == 'No'
            without_side_effects << data['patient_id']
          else
            unknowns << data['patient_id']
          end
        end

        return [with_side_effects, without_side_effects, unknowns]
      end

      COHORT_REGIMENS = %w[
        0P 2P 4P 9P 11P 14P 15P 16P 17P 0A 2A 4A
        5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A
        16A 17A
      ].freeze

      def cal_regimem_category(_patient_list, end_date)
        Cohort::Regimens.patient_regimens(end_date).map do |prescription|
          regimen = prescription['regimen_category']

          if regimen == 'Unknown' || !COHORT_REGIMENS.include?(regimen)
            regimen = 'unknown_regimen'
          end

          {
            patient_id: prescription['patient_id'],
            regimen_category: regimen,
            drugs: prescription['drugs'].split(',').collect(&:to_i),
            prescription_date: prescription['prescription_date']
          }
        end
      end

      def filter_prescriptions_by_regimen(prescriptions, regimen)
        prescriptions.select do |prescription|
          prescription[:regimen_category].casecmp?(regimen)
        end
      end

      def filter_prescriptions_by_drugs(prescriptions, drug_ids)
        prescriptions.select do |prescription|
          prescription[:drugs].find { |drug_id| drug_ids.include?(drug_id) }
        end
      end

      def died_in(month_str)
        registered = []
        if month_str == '4+ months'
          data = ActiveRecord::Base.connection.select_all(
            "SELECT patient_id, died_in(t.patient_id, cum_outcome, date_enrolled) died_in FROM temp_patient_outcomes o
            INNER JOIN temp_earliest_start_date t USING(patient_id)
            WHERE cum_outcome = 'Patient died' GROUP BY patient_id
            HAVING died_in IN ('4+ months', 'Unknown')"
          )
        else
          data = ActiveRecord::Base.connection.select_all(
            "SELECT patient_id, died_in(t.patient_id, cum_outcome, date_enrolled) died_in FROM temp_patient_outcomes o
            INNER JOIN temp_earliest_start_date t USING(patient_id)
            WHERE cum_outcome = 'Patient died' GROUP BY patient_id
            HAVING died_in = '#{month_str}'"
          )
        end

        (data || []).each do |patient|
          registered << patient['patient_id']
        end

        registered
      end

      def get_outcome(outcome)
        sql_patch = if outcome == 'Pre-ART (Continue)'
                      "cum_outcome = '#{outcome}' OR cum_outcome = 'Unknown'"
                    else
                      "cum_outcome = '#{outcome}'"
                    end

        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_patient_outcomes WHERE #{sql_patch} GROUP BY patient_id"
        )
      end

      def kaposis_sarcoma(start_date, end_date)
        # KAPOSIS SARCOMA
        concept_id = concept('KAPOSIS SARCOMA').concept_id
        yes_concept_id = concept('Yes').concept_id
        who_stages_criteria = concept('Who stages criteria present').concept_id

        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date t
          INNER JOIN obs ON t.patient_id = obs.person_id
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND ((value_coded = #{concept_id} AND concept_id = #{who_stages_criteria})
          OR (concept_id = #{concept_id}) AND value_coded = #{yes_concept_id} )
          AND voided = 0 AND DATE(obs_datetime) <= DATE(date_enrolled) GROUP BY patient_id"
        )
      end

      def current_episode_of_tb(start_date, end_date)
        # CURRENT EPISODE OF TB
        eptb_concept_id = concept('EXTRAPULMONARY TUBERCULOSIS (EPTB)').concept_id
        yes_concept_id = concept('Yes').concept_id
        pulmonary_tb_concept_id = concept('PULMONARY TUBERCULOSIS').concept_id
        current_ptb_concept_id = concept('PULMONARY TUBERCULOSIS (CURRENT)').concept_id

        who_stages_criteria = concept('Who stages criteria present').concept_id

        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date t
          INNER JOIN obs ON t.patient_id = obs.person_id
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND ( (value_coded IN (#{eptb_concept_id}, #{pulmonary_tb_concept_id}, #{current_ptb_concept_id}) AND concept_id = #{who_stages_criteria} )
          OR (concept_id IN (#{eptb_concept_id}, #{pulmonary_tb_concept_id}, #{current_ptb_concept_id}) AND value_coded = #{yes_concept_id}))
          AND voided = 0 AND DATE(obs_datetime) <= DATE(date_enrolled) GROUP BY patient_id"
        )
      end

      def tb_within_the_last_two_years(patients_with_current_tb, start_date, end_date)
        # patients with current episode of tb
        patients_with_current_tb_episode = []
        (patients_with_current_tb || []).each do |patient|
          patients_with_current_tb_episode << patient['patient_id'].to_i
        end

        patients_with_current_tb_episode = [0] if patients_with_current_tb_episode.blank?

        # Pulmonary tuberculosis within the last 2 years
        pulmonary_tb_within_last_2yrs_concept_id = concept('Pulmonary tuberculosis within the last 2 years').concept_id
        ptb_within_the_past_two_yrs_concept_id = concept('Ptb within the past two years').concept_id
        who_stages_criteria = concept('Who stages criteria present').concept_id
        yes_concept_id = concept('Yes').concept_id

        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date t
          INNER JOIN obs ON t.patient_id = obs.person_id
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND ((value_coded IN (#{pulmonary_tb_within_last_2yrs_concept_id}, #{ptb_within_the_past_two_yrs_concept_id})
            AND concept_id = #{who_stages_criteria})
            OR (concept_id IN (#{pulmonary_tb_within_last_2yrs_concept_id}, #{ptb_within_the_past_two_yrs_concept_id}) AND value_coded = #{yes_concept_id}))
            AND patient_id NOT IN (#{patients_with_current_tb_episode.join(',')})
            AND voided = 0 AND DATE(obs_datetime) <= DATE(date_enrolled) GROUP BY patient_id"
        )
      end

      def no_tb(total_registered, tb_within_the_last_two_years, current_episode_of_tb)
        total_registered_patients = []
        tb_within_2yrs_patients = []
        current_tb_episode_patients = []
        result = []

        (total_registered || []).each do |patient|
          total_registered_patients << patient['patient_id'].to_i
        end

        (tb_within_the_last_two_years || []).each do |patient|
          tb_within_2yrs_patients << patient['patient_id'].to_i
        end

        (current_episode_of_tb || []).each do |patient|
          current_tb_episode_patients << patient['patient_id'].to_i
        end

        result = total_registered_patients - (tb_within_2yrs_patients + current_tb_episode_patients)

        result
      end

      def cum_no_tb(cum_total_registered, cum_tb_within_the_last_two_years, cum_current_episode_of_tb)
        total_registered_patients = []
        tb_within_2yrs_patients = []
        current_tb_episode_patients = []
        result = []

        (cum_total_registered || []).each do |patient|
          total_registered_patients << patient['patient_id'].to_i
        end

        (cum_tb_within_the_last_two_years || []).each do |patient|
          tb_within_2yrs_patients << patient['patient_id'].to_i
        end

        (cum_current_episode_of_tb || []).each do |patient|
          current_tb_episode_patients << patient['patient_id'].to_i
        end

        result = total_registered_patients - (tb_within_2yrs_patients + current_tb_episode_patients)
        result
      end

      def children_12_59_months(start_date, end_date)
        concept = ConceptName.where(name: 'HIV Infected').select(:concept_id)

        find_patients_by_reason_for_starting(start_date, end_date, concept)
      end

      def unknown_other_reason_outside_guidelines(start_date, end_date)
        # All WHO stage 1 and 2 patients that were enrolled before '2016-04-01'
        # should be included in this group.
        unknown_concepts = ConceptName.where(name: ['Unknown', 'None'])
                                      .select(:concept_id)
                                      .to_sql

        if start_date.to_date > '2016-04-01'.to_date
          return ActiveRecord::Base.connection.select_all <<~SQL
            SELECT patient_id FROM temp_earliest_start_date
            WHERE reason_for_starting_art IN (#{unknown_concepts})
              AND date_enrolled >= '#{start_date}'
              AND date_enrolled <= '#{end_date}'
          SQL
        end

        stage_1_and_2_concept_names = ['LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1',
                                       'LYMPHOCYTES',
                                       'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2',
                                       'WHO stage I adult',
                                       'WHO stage I peds',
                                       'WHO STAGE 1',
                                       'WHO stage II adult',
                                       'WHO stage II peds',
                                       'WHO STAGE 2']

        stage_1_and_2_concepts = ConceptName.where(name: stage_1_and_2_concept_names)
                                            .select('DISTINCT concept_id')
                                            .to_sql

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_id FROM temp_earliest_start_date
          WHERE
            (
              reason_for_starting_art IN (#{unknown_concepts})
              AND date_enrolled >= '#{start_date}'
              AND date_enrolled <= '#{end_date}'
            )
            OR (
              reason_for_starting_art IN (#{stage_1_and_2_concepts})
              AND date_enrolled <= DATE('2016-04-01')
            )
        SQL
      end

      def who_stage_four(start_date, end_date)
        concepts = ConceptName.where(name: ['WHO stage IV adult', 'WHO stage IV peds', 'WHO STAGE 4'])
                              .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concepts)
      end

      def who_stage_three(start_date, end_date)
        concepts = ConceptName.where(name: ['WHO stage III adult', 'WHO stage III peds', 'WHO STAGE 3'])
                              .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concepts)
      end

      def pregnant_women(start_date, end_date)
        concepts = ConceptName.where(name: ['PATIENT PREGNANT', 'Is patient pregnant at initiation?',
                                            'Patient pregnant state', 'Is patient pregnant?'])
                              .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concepts)
      end

      def breastfeeding_mothers(start_date, end_date)
        concept = ConceptName.where(name: 'Breastfeeding').select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concept)
      end

      def asymptomatic(start_date, end_date)
        # for WHO stage 1 and 2 to be included in asymptomatic, the patients are supposed to
        # be enrolled on HIV program after 2016-04-01
        patients = []

        asymptomatic_concepts = ConceptName.where(name: ['ASYMPTOMATIC', 'Asymptomatic HIV infection'])
                                           .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, asymptomatic_concepts)
          .each { |patient| patients << patient['patient_id'] }

        reason_concepts = ConceptName.where(name: ['WHO stage I adult',
                                                   'WHO stage I peds',
                                                   'WHO stage 1',
                                                   'WHO stage II adult',
                                                   'WHO stage II peds',
                                                   'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1',
                                                   'LYMPHOCYTES',
                                                   'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2'])
                                     .select(:concept_id)

        revised_art_guidelines_date = '2016-04-01'.to_date
        start_date = revised_art_guidelines_date if start_date.to_date < revised_art_guidelines_date

        find_patients_by_reason_for_starting(start_date, end_date, reason_concepts)
          .each { |patient| patients << patient['patient_id'] }

        patients
      end

      def who_stage_two(start_date, end_date)
        concepts = ConceptName.where(name: ['CD4 COUNT LESS THAN OR EQUAL TO 750',
                                            'CD4 count less than or equal to 500',
                                            'CD4 COUNT LESS THAN OR EQUAL TO 350',
                                            'CD4 COUNT LESS THAN OR EQUAL TO 250'])
                              .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concepts)
      end

      def confirmed_hiv_infection_in_infants_pcr(start_date, end_date)
        concept = ConceptName.where(name: 'HIV PCR').select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concept)
      end

      def presumed_severe_hiv_disease_in_infants(start_date, end_date)
        concepts = ConceptName.where(name: ['PRESUMED SEVERE HIV',
                                            'PRESUMED SEVERE HIV CRITERIA IN INFANTS'])
                              .select(:concept_id)
        find_patients_by_reason_for_starting(start_date, end_date, concepts)
      end

      def find_patients_by_reason_for_starting(start_date, end_date, reason_concept_ids)
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_id
          FROM temp_earliest_start_date
          WHERE date_enrolled >= '#{start_date}'
            AND date_enrolled <= '#{end_date}'
            AND reason_for_starting_art IN (#{reason_concept_ids.to_sql})
        SQL
      end

      def unknown_age(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND (age_at_initiation IS NULL OR age_at_initiation < 0 OR birthdate IS NULL)
          GROUP BY patient_id"
        )
      end

      def unknown_gender(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND gender IS NULL OR LENGTH(gender) < 1  GROUP BY patient_id;"
        )
      end

      def adults_at_art_initiation(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND age_at_initiation > 14 GROUP BY patient_id"
        )
      end

      def children_24_months_14_years_at_art_initiation(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND age_at_initiation BETWEEN  2 AND 14 GROUP BY patient_id"
        )
      end

      def children_below_24_months_at_art_initiation(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND (age_at_initiation >= 0 AND age_at_initiation < 2) GROUP BY patient_id"
        )
      end

      def non_pregnant_females(start_date, end_date, pregnant_women = [])
        registered = []; pregnant_women_ids = []
        (pregnant_women || []).each do |patient|
          pregnant_women_ids << patient
        end
        pregnant_women_ids = [0] if pregnant_women_ids.blank?

        ActiveRecord::Base.connection.select_all(
          "SELECT t.patient_id FROM temp_earliest_start_date t
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND (gender = 'F' OR gender = 'Female')
          AND t.patient_id NOT IN(#{pregnant_women_ids.join(',')}) GROUP BY patient_id"
        )
      end

      def pregnant_females_all_ages(start_date, end_date)
        yes_concept_id = concept('Yes').concept_id
        preg_concept_id = concept('IS PATIENT PREGNANT?').concept_id
        patient_preg_concept_id = concept('PATIENT PREGNANT').concept_id
        preg_at_initiation_concept_id = concept('PREGNANT AT INITIATION?').concept_id
        reason_for_starting_concept_id = concept('Reason for ART eligibility').concept_id

        # (patient_id_plus_date_enrolled || []).each do |patient_id, date_enrolled|
        registered = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patients.*, obs.value_coded
          FROM temp_earliest_start_date AS patients
          INNER JOIN obs
            ON obs.person_id = patients.patient_id
            AND obs.concept_id IN (#{preg_concept_id},
                                   #{patient_preg_concept_id},
                                   #{preg_at_initiation_concept_id},
                                   #{reason_for_starting_concept_id})
            AND obs.obs_datetime >= patients.earliest_start_date
            AND obs.obs_datetime < (patients.earliest_start_date + INTERVAL 1 DAY)
            AND obs.value_coded IS NOT NULL
            AND obs.voided = 0
          WHERE patients.gender IN ('F', 'Female')
            AND patients.date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          GROUP BY patient_id
          HAVING value_coded = #{yes_concept_id} OR value_coded = #{patient_preg_concept_id}
        SQL

        pregnant_at_initiation = ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, patient_reason_for_starting_art(patient_id) reason_concept_id
          FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND (gender = 'F' OR gender = 'Female')
          GROUP BY patient_id
          HAVING reason_concept_id IN (1755, 7972, 6131);"
        )
        pregnant_at_initiation_ids = []
        (pregnant_at_initiation || []).each do |patient|
          pregnant_at_initiation_ids << patient['patient_id'].to_i
        end

        pregnant_at_initiation_ids = [0] if pregnant_at_initiation_ids.blank?

        transfer_ins_women = ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, re_initiated_check(patient_id, date_enrolled) re_initiated
          FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND DATE(date_enrolled) != DATE(earliest_start_date)
            AND (gender = 'F' OR gender = 'Female')
            AND patient_id IN (#{pregnant_at_initiation_ids.join(',')})
          GROUP BY patient_id
          HAVING re_initiated != 'Re-initiated'"
        )

        transfer_ins_preg_women = []; all_pregnant_females = []
        (transfer_ins_women || []).each do |patient|
          if patient['patient_id'].to_i != 0
            transfer_ins_preg_women << patient['patient_id'].to_i
          end
        end

        (registered || []).each do |patient|
          if patient['patient_id'].to_i != 0
            all_pregnant_females << patient['patient_id'].to_i
          end
        end

        all_pregnant_females = (all_pregnant_females + transfer_ins_preg_women).uniq
        all_pregnant_females
      end

      def initial_females_all_ages(start_date, end_date, data)
        clients = []
        women = ActiveRecord::Base.connection.select_all("
        SELECT * FROM temp_earliest_start_date e
        WHERE patient_id IN(#{(data.length > 0 ? data.join(',') : 0)})
        AND date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
        AND DATE(date_enrolled) = DATE(earliest_start_date);")

        (women || []).each do |w|
          clients << w
        end

        return clients
      end

      def males(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date t
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND (gender = 'Male' OR gender = 'M') GROUP BY patient_id"
        )
      end

      def transfer_in(start_date, end_date, re_initiated_on_art)
        start_date = ActiveRecord::Base.connection.quote(start_date)
        end_date = ActiveRecord::Base.connection.quote(end_date)

        re_initiated_on_art = re_initiated_on_art.empty? ? [0] : re_initiated_on_art.rows.collect(&:first)

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT temp_earliest_start_date.patient_id
          FROM temp_earliest_start_date
          INNER JOIN clinic_registration_encounter
            ON clinic_registration_encounter.patient_id = temp_earliest_start_date.patient_id
          LEFT JOIN ever_registered_obs
            ON ever_registered_obs.person_id = temp_earliest_start_date.patient_id
            AND ever_registered_obs.value_coded = (
              SELECT concept_id FROM concept_name WHERE name = 'Yes' AND voided = 0 LIMIT 1
            )
          LEFT JOIN (
              SELECT person_id, MIN(obs_datetime) AS obs_datetime
              FROM ever_registered_obs
              GROUP BY person_id
            ) AS max_ever_registered_obs
              ON max_ever_registered_obs.person_id = ever_registered_obs.person_id
              AND max_ever_registered_obs.obs_datetime = ever_registered_obs.obs_datetime
          LEFT JOIN obs AS last_taken_art_obs
            ON last_taken_art_obs.encounter_id = ever_registered_obs.encounter_id
            AND last_taken_art_obs.voided = 0
            AND last_taken_art_obs.concept_id = (
              SELECT concept_id FROM concept_name WHERE name = 'DATE ART LAST TAKEN' LIMIT 1
            )
          WHERE (date_enrolled BETWEEN #{start_date} AND #{end_date})
            AND date_enrolled != earliest_start_date
            AND COALESCE(TIMESTAMPDIFF(day,
                                       last_taken_art_obs.value_datetime,
                                       last_taken_art_obs.obs_datetime) <= 14,
                        TRUE)
            AND temp_earliest_start_date.patient_id NOT IN (#{re_initiated_on_art.join(',')})
          GROUP BY temp_earliest_start_date.patient_id;
        SQL
      end

      def re_initiated_on_art(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          <<~SQL
            SELECT temp_earliest_start_date.patient_id
            FROM temp_earliest_start_date
            INNER JOIN clinic_registration_encounter
              ON temp_earliest_start_date.patient_id = clinic_registration_encounter.patient_id
            INNER JOIN ever_registered_obs
              ON clinic_registration_encounter.encounter_id = ever_registered_obs.encounter_id
              AND ever_registered_obs.value_coded = (SELECT concept_id FROM concept_name
                WHERE name = 'Yes' AND voided = 0 LIMIT 1)
            INNER JOIN (
              SELECT person_id, MIN(obs_datetime) AS obs_datetime
              FROM ever_registered_obs
              GROUP BY person_id
            ) AS max_ever_registered_obs
              ON max_ever_registered_obs.person_id = ever_registered_obs.person_id
              AND max_ever_registered_obs.obs_datetime = ever_registered_obs.obs_datetime
            INNER JOIN obs AS last_taken_art_obs
              ON last_taken_art_obs.encounter_id = clinic_registration_encounter.encounter_id
              AND last_taken_art_obs.voided = 0
              AND last_taken_art_obs.concept_id = (
                SELECT concept_id FROM concept_name WHERE name = 'DATE ART LAST TAKEN' LIMIT 1
              )
            WHERE (date_enrolled BETWEEN '#{start_date}' AND '#{end_date}')
              AND TIMESTAMPDIFF(day,
                                last_taken_art_obs.value_datetime,
                                last_taken_art_obs.obs_datetime) > 14
              AND date_enrolled != earliest_start_date
            GROUP BY temp_earliest_start_date.patient_id;
          SQL
        )
      end

      def initiated_on_art_first_time(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND date_enrolled = earliest_start_date
          GROUP BY patient_id"
        )
      end

      def males_initiated_on_art_first_time(start_date, end_date, data)
        clients = []
        (data || []).each do |e|
          gender = e['gender']&.upcase&.first
          next if gender.blank?
          next unless gender == 'M'
          date_enrolled = e['date_enrolled'].to_date
          start_date = start_date.to_date
          end_date = end_date.to_date
          (date_enrolled >= start_date && date_enrolled <= end_date) ? clients << e : next
        end

        return clients
      end

      def get_cum_start_date
        cum_start_date = ActiveRecord::Base.connection.select_value(
          'SELECT MIN(date_enrolled) FROM temp_earliest_start_date'
        )

        begin
          return cum_start_date.to_date
        rescue StandardError
          nil
        end
      end

      def total_registered(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          GROUP BY patient_id"
        )
      end

      def load_tmp_patient_table(cohort_struct)
        create_tmp_patient_table
=begin
        arv_orders.each_with_object({}) do |order, patient_tab|
          next if patient_tab.include?(order.patient_id)

          person = Person.find(order.patient_id)
          next unless person.birthdate # && patient_in_program?(person.patient)

          add_patient_record(person, order, cohort_struct)

          patient_tab[order.patient_id] = person
        end
=end
      end

        def create_tmp_patient_table_2(end_date)

    ##########################################################
    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS patient_date_enrolled;
EOF

    arv_concept_ids = Drug.arv_drugs.map(&:concept_id)

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION patient_date_enrolled(my_patient_id int) RETURNS DATE
DETERMINISTIC
BEGIN
DECLARE my_start_date DATE;
DECLARE min_start_date DATETIME;
DECLARE arv_concept_id INT(11);

SET arv_concept_id = (SELECT concept_id FROM concept_name WHERE name ='ANTIRETROVIRAL DRUGS' LIMIT 1);

SET my_start_date = (SELECT DATE(o.start_date) FROM drug_order d INNER JOIN orders o ON d.order_id = o.order_id AND o.voided = 0 WHERE o.patient_id = my_patient_id AND drug_inventory_id IN(SELECT drug_id FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = arv_concept_id)) AND d.quantity > 0 AND o.start_date = (SELECT min(start_date) FROM drug_order d INNER JOIN orders o ON d.order_id = o.order_id AND o.voided = 0 WHERE d.quantity > 0 AND o.patient_id = my_patient_id AND drug_inventory_id IN(SELECT drug_id FROM drug WHERE concept_id IN(SELECT concept_id FROM concept_set WHERE concept_set = arv_concept_id))) LIMIT 1);


RETURN my_start_date;
END;
EOF
    ##########################################################




    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `temp_earliest_start_date`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE temp_earliest_start_date
        select
            `p`.`patient_id` AS `patient_id`,
            `pe`.`gender` AS `gender`,
            `pe`.`birthdate`,
            date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
            cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
            `person`.`death_date` AS `death_date`,
            (select timestampdiff(year, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_at_initiation`,
            (select timestampdiff(day, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_in_days`
        from
            ((`patient_program` `p`
            left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
            left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
            left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
        where
            ((`p`.`voided` = 0)
                and (`s`.`voided` = 0)
                and (`p`.`program_id` = 1)
                and (`s`.`state` = 7))
        group by `p`.`patient_id`;
EOF

  end

      def arv_orders
        Order.joins(:drug_order).where(
          'drug_order.drug_inventory_id in (?)', Drug.arv_drugs.collect(&:drug_id)
        ).order(:start_date)
      end

      def add_patient_record(person, order, cohort_struct)
        date_enrolled = order.start_date.to_date
        art_earliest_start_date = patient_earliest_start_date(order.patient_id, date_enrolled)

        if date_enrolled == art_earliest_start_date
          cohort_struct.cum_initiated_on_art_first_time ||= 0
          cohort_struct.cum_initiated_on_art_first_time += 1
        end

        age_in_months_when_starting = (art_earliest_start_date - person.birthdate).to_i
        age_when_starting = (age_in_months_when_starting / 365).to_i
        deathdate = person.death_date ? "'#{person.death_date.to_date}'" : 'NULL'

        ActiveRecord::Base.connection.execute(
          "INSERT INTO temp_earliest_start_date (
              patient_id,
              date_enrolled,
              earliest_start_date,
              gender,
              birthdate,
              birthdate_estimated,
              death_date,
              age_at_initiation,
              age_in_days
           ) VALUES (
              #{order.patient_id},
              '#{order.start_date.to_date}',
              '#{art_earliest_start_date.to_date}',
              '#{person.gender}',
              '#{person.birthdate}',
              '#{person.birthdate_estimated}',
              #{deathdate},
              '#{age_when_starting}',
              '#{age_in_months_when_starting}'
           )"
        )
      end

      # Retrieve the earliest (clinic?) start date for a patient
      def patient_earliest_start_date(patient_id, min_start_date)
        result = ActiveRecord::Base.connection.select_one(
          "SELECT date_antiretrovirals_started(
            #{patient_id}, '#{min_start_date.to_date}'
           ) AS date"
        )
        result['date'].to_date
      end

      # Returns a list of reasons for starting ART for each patient.
      def patients_art_start_reason(patient_ids)
        ActiveRecord::Base.connection.execute(
          "SELECT person_id as patient_id, name, obs_datetime
           FROM reason_for_art_eligibility_obs
           WHERE person_id IN (#{patient_ids.join(',')})"
        )
      end

      def patient_death_date(patient)
        PatientState.find_by(program: program('HIV Program'), patient: patient)
      end

      # Filter out patients with given start causes from patient_ids
      def filter_patients_with_start_cause(patient_ids, start_cause_concept_ids)
        obs_concepts = start_cause_concept_ids.push(concept('WHO STAGES CRITERIA PRESENT').concept_id)
        obs_values = start_cause_concept_ids.push(concept('YES').concept_id)

        ActiveRecord::Base.connection.execute(
          "SELECT * FROM hiv_staging_conditions_obs
           WHERE concept_id IN (#{obs_concepts.join(',')})
            AND value_coded IN (#{obs_values.join(',')})
            AND person_id IN (#{patient_ids.join(',')})
           GROUP BY person_id"
        )
      end

      def patient_in_program?(patient)
        return false unless patient

        pprogram = PatientProgram.find_by(program: program('HIV Program'), patient: patient)
        return false unless pprogram

        PatientState.where(patient_program: pprogram, state: 7).exists?
      end
    end
  end
end
