# frozen_string_literal: true

require_relative './cohort/tpt'

module ArtService
  module Reports
    class CohortBuilder
      QUARTER_LENGTH = 3.months

      include ModelUtils
      include CommonSqlQueryUtils
      include ArtTempTablesUtils

      def initialize(outcomes_definition: 'moh')
        unless %w[moh pepfar].include?(outcomes_definition.downcase)
          raise ArgumentError, "Invalid outcomes_definition `#{outcomes_definition}` expected moh or pepfar"
        end

        @outcomes_definition = outcomes_definition
      end

      def init_temporary_tables(start_date, end_date, occupation)
        prepare_tables
        load_phase1_parallel(end_date)
        load_data_into_temp_earliest_start_date(end_date.to_date, occupation)
        update_cum_outcome(start_date:, end_date:)
      end

      def build(cohort_struct, start_date, end_date, occupation, progress_key: nil)
        # load_tmp_patient_table(cohort_struct)
        CohortProgress.step!(progress_key, :prepare) if progress_key
        prepare_tables
        CohortProgress.step!(progress_key, :phase1) if progress_key
        load_phase1_parallel(end_date)
        CohortProgress.step!(progress_key, :enroll) if progress_key
        load_data_into_temp_earliest_start_date(end_date.to_date, occupation)

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

        cohort_struct.males_initiated_on_art_first_time = males_initiated_on_art_first_time(start_date, end_date,
                                                                                            cohort_struct.initiated_on_art_first_time)
        cohort_struct.cum_males_initiated_on_art_first_time = males_initiated_on_art_first_time(cum_start_date,
                                                                                                end_date, cohort_struct.cum_initiated_on_art_first_time)

        # Patients re-initiated on ART
        # Precompute MIN(ever-registered obs datetime) per patient once — used by all 3 re-initiated
        # and all 3 transfer_in calls instead of the inline GROUP BY subquery run 6 times.
        precompute_min_ever_reg_obs
        cohort_struct.re_initiated_on_art = re_initiated_on_art(start_date, end_date)
        cohort_struct.cum_re_initiated_on_art = re_initiated_on_art(cum_start_date, end_date)
        cohort_struct.quarterly_re_initiated_on_art = re_initiated_on_art(quarter_start_date, end_date)

        # Patients transferred in on ART
        cohort_struct.transfer_in = transfer_in(start_date, end_date, cohort_struct.re_initiated_on_art)
        cohort_struct.cum_transfer_in = transfer_in(cum_start_date, end_date, cohort_struct.cum_re_initiated_on_art)
        cohort_struct.quarterly_transfer_in = transfer_in(quarter_start_date, end_date,
                                                          cohort_struct.quarterly_re_initiated_on_art)

        # All males
        cohort_struct.all_males = males(start_date, end_date)
        cohort_struct.cum_all_males = males(cum_start_date, end_date)
        cohort_struct.quarterly_all_males = males(quarter_start_date, end_date)

        CohortProgress.step!(progress_key, :demographics) if progress_key
        # Pregnant females (all ages)
        load_temp_pregnant_obs(cum_start_date, end_date)
        cohort_struct.pregnant_females_all_ages = pregnant_females_all_ages(start_date, end_date)
        cohort_struct.cum_pregnant_females_all_ages = pregnant_females_all_ages(cum_start_date, end_date)
        cohort_struct.quarterly_pregnant_females_all_ages = pregnant_females_all_ages(quarter_start_date, end_date)

        cohort_struct.initial_pregnant_females_all_ages = initial_females_all_ages(start_date, end_date,
                                                                                   cohort_struct.pregnant_females_all_ages)
        cohort_struct.cum_initial_pregnant_females_all_ages = initial_females_all_ages(cum_start_date, end_date,
                                                                                       cohort_struct.cum_pregnant_females_all_ages)

        # Non-pregnant females (all ages)
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having gender of
        # related PERSON entry as F for female and no entries of 'IS PATIENT PREGNANT?' observation answered 'YES'
        # in related HIV CLINIC CONSULTATION encounters not within 28 days from earliest registration date
        cohort_struct.non_pregnant_females = non_pregnant_females(start_date, end_date,
                                                                  cohort_struct.pregnant_females_all_ages)
        cohort_struct.cum_non_pregnant_females = non_pregnant_females(cum_start_date, end_date,
                                                                      cohort_struct.cum_pregnant_females_all_ages)
        cohort_struct.quarterly_non_pregnant_females = non_pregnant_females(quarter_start_date, end_date,
                                                                            cohort_struct.cum_pregnant_females_all_ages)

        cohort_struct.initial_non_pregnant_females_all_ages = initial_females_all_ages(start_date, end_date, cohort_struct.non_pregnant_females.map do |a|
                                                                                                               a['patient_id']
                                                                                                             end)
        cohort_struct.cum_initial_non_pregnant_females_all_ages = initial_females_all_ages(cum_start_date, end_date, cohort_struct.cum_non_pregnant_females.map do |a|
                                                                                                                       a['patient_id']
                                                                                                                     end)

        # Children below 24 months at ART initiation
        cohort_struct.children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(
          start_date, end_date
        )
        cohort_struct.cum_children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(
          cum_start_date, end_date
        )
        cohort_struct.quarterly_children_below_24_months_at_art_initiation = children_below_24_months_at_art_initiation(
          quarter_start_date, end_date
        )

        # Children 24 months – 14 years at ART initiation
        cohort_struct.children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(
          start_date, end_date
        )
        cohort_struct.cum_children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(
          cum_start_date, end_date
        )
        cohort_struct.quarterly_children_24_months_14_years_at_art_initiation = children_24_months_14_years_at_art_initiation(
          quarter_start_date, end_date
        )

        # Adults at ART initiation
        cohort_struct.adults_at_art_initiation = adults_at_art_initiation(start_date, end_date)
        cohort_struct.cum_adults_at_art_initiation = adults_at_art_initiation(cum_start_date, end_date)
        cohort_struct.quarterly_adults_at_art_initiation = adults_at_art_initiation(quarter_start_date, end_date)

        # Unknown age
        cohort_struct.unknown_age = unknown_age(start_date, end_date)
        cohort_struct.cum_unknown_age = unknown_age(cum_start_date, end_date)
        cohort_struct.quarterly_unknown_age = unknown_age(quarter_start_date, end_date)

        # Unknown gender
        cohort_struct.unknown_gender = unknown_gender(start_date, end_date)
        cohort_struct.cum_unknown_gender = unknown_gender(cum_start_date, end_date)

        # Unique PatientProgram entries at the current location for those
        # patients with at least one state ON ARVs and earliest start date
        # of the 'ON ARVs' state within the quarter and having a
        # REASON FOR ELIGIBILITY observation with an answer as PRESUMED SEVERE HIV
        cohort_struct.presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(start_date,
                                                                                                      end_date)
        cohort_struct.cum_presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(
          cum_start_date, end_date
        )
        cohort_struct.quarterly_presumed_severe_hiv_disease_in_infants = presumed_severe_hiv_disease_in_infants(
          quarter_start_date, end_date
        )

        # Confirmed HIV infection in infants (PCR)

        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and
        # having a REASON FOR ELIGIBILITY observation with an answer as HIV PCR
        cohort_struct.confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(start_date,
                                                                                                      end_date)
        cohort_struct.cum_confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(
          cum_start_date, end_date
        )
        cohort_struct.quarterly_confirmed_hiv_infection_in_infants_pcr = confirmed_hiv_infection_in_infants_pcr(
          quarter_start_date, end_date
        )

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
        cohort_struct.unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(start_date,
                                                                                                        end_date)
        cohort_struct.cum_unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(
          cum_start_date, end_date
        )
        cohort_struct.quarterly_unknown_other_reason_outside_guidelines = unknown_other_reason_outside_guidelines(
          quarter_start_date, end_date
        )

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
        cohort_struct.tb_within_the_last_two_years = tb_within_the_last_two_years(cohort_struct.current_episode_of_tb,
                                                                                  start_date, end_date)
        cohort_struct.cum_tb_within_the_last_two_years = tb_within_the_last_two_years(
          cohort_struct.cum_current_episode_of_tb, cum_start_date, end_date
        )
        cohort_struct.quarterly_tb_within_the_last_two_years = tb_within_the_last_two_years(
          cohort_struct.quarterly_current_episode_of_tb, quarter_start_date, end_date
        )

        # No TB
        # total_registered - (current_episode - tb_within_the_last_two_years)
        cohort_struct.no_tb = no_tb(cohort_struct.total_registered, cohort_struct.tb_within_the_last_two_years,
                                    cohort_struct.current_episode_of_tb)
        cohort_struct.cum_no_tb = cum_no_tb(cohort_struct.cum_total_registered,
                                            cohort_struct.cum_tb_within_the_last_two_years, cohort_struct.cum_current_episode_of_tb)
        cohort_struct.quarterly_no_tb = cum_no_tb(cohort_struct.quarterly_total_registered,
                                                  cohort_struct.quarterly_tb_within_the_last_two_years, cohort_struct.quarterly_current_episode_of_tb)

        # Kaposis Sarcoma
        #
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having a KAPOSIS SARCOMA observation
        # at the HIV staging encounter on the initiation date
        cohort_struct.kaposis_sarcoma = kaposis_sarcoma(start_date, end_date)
        cohort_struct.cum_kaposis_sarcoma = kaposis_sarcoma(cum_start_date, end_date)
        cohort_struct.quarterly_kaposis_sarcoma = kaposis_sarcoma(quarter_start_date, end_date)

        # TPT reads only orders/obs/temp_earliest_start_date.patient_id — no dependency on
        # temp_patient_outcomes — so it is safe to pre-fetch concurrently with update_cum_outcome.
        tpt_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            tpt_obj = Cohort::Tpt.new(start_date, end_date)
            { tpt_3hp: tpt_obj.newly_initiated_on_3hp, tpt_ipt: tpt_obj.newly_initiated_on_ipt }
          end
        end

        # From this point going down: we update temp_earliest_start_date cum_outcome field to have the latest Cumulative outcome
        CohortProgress.step!(progress_key, :cum_outcome) if progress_key
        update_cum_outcome(start_date: quarter_start_date, end_date:)

        # Pre-load tmp_max_adherence in a background thread while the remaining indicator
        # queries run. This overlaps the cold-buffer-pool obs I/O (~391s) with ~165s of
        # indicator computation, saving ~146s wall time on a cold database.
        # temp_patient_outcomes (just populated by update_cum_outcome) is required.
        CohortProgress.step!(progress_key, :preloads) if progress_key
        _quoted_end_for_adherence = ActiveRecord::Base.connection.quote(end_date)
        @adherence_preload_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection { load_tmp_max_adherence(_quoted_end_for_adherence) }
        end

        # Pre-load obs at last drug-order visit for pregnant/breastfeeding concepts in parallel
        # with the adherence preload. Runs over the same female ART patient obs pages, so I/O
        # overlaps with adherence instead of adding ~350 s sequentially after adherence.
        # When done, total_pregnant_women and total_breastfeeding_women become near-instant.
        _quoted_end_for_obs_lv = ActiveRecord::Base.connection.quote(end_date)
        @obs_last_visit_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection { load_temp_obs_last_visit(_quoted_end_for_obs_lv) }
        end

        # update_tb_status and update_patient_side_effects both JOIN temp_patient_outcomes
        # (populated above) but write to separate tables — safe to run in parallel.
        [
          Thread.new { ActiveRecord::Base.connection_pool.with_connection { update_tb_status(end_date) } },
          Thread.new { ActiveRecord::Base.connection_pool.with_connection { update_patient_side_effects(end_date) } }
        ].each(&:join)

        CohortProgress.step!(progress_key, :outcomes) if progress_key
        # Total Alive and On ART
        # Unique PatientProgram entries at the current location for those patients with at least one state
        # ON ARVs and earliest start date of the 'ON ARVs' state less than or equal to end date of quarter
        # and latest state is ON ARVs  (Excluding defaulters)
        cohort_struct.total_alive_and_on_art = get_outcome('On antiretrovirals')
        # Single query replaces 4 separate calls to died_in() stored function (per-row sub-queries).
        died_in_buckets = all_died_in_buckets
        cohort_struct.died_within_the_1st_month_of_art_initiation = died_in_buckets['1st month'] || []
        cohort_struct.died_within_the_2nd_month_of_art_initiation = died_in_buckets['2nd month'] || []
        cohort_struct.died_within_the_3rd_month_of_art_initiation = died_in_buckets['3rd month'] || []
        cohort_struct.died_after_the_3rd_month_of_art_initiation  = died_in_buckets['4+ months'] || []
        cohort_struct.died_total                                  = get_outcome('Patient died')
        cohort_struct.defaulted                                   = get_outcome('Defaulted')
        cohort_struct.stopped_art                                 = get_outcome('Treatment stopped')
        cohort_struct.transfered_out                              = get_outcome('Patient transferred out')
        cohort_struct.unknown_outcome                             = get_outcome('Pre-ART (Continue)')

        # ARV Regimen category
        # Alive and On ART and Value Coded of the latest 'Regimen Category' Observation
        # of each patient that is linked to the Dispensing encounter in the reporting period

        prescriptions = cal_regimem_category(cohort_struct.total_alive_and_on_art, end_date)

        CohortProgress.step!(progress_key, :regimens) if progress_key
        # drugs = ->(concepts) { Drug.where(concept: concepts).select(:drug_id).collect(&:drug_id) }

        # lpv_granules = drugs[concepts[['LPV/r Pellets', 'LPV/r Granules']]]
        # lpv_tabs = drugs[concepts['LPV/r']]

        cohort_struct.zero_p            = filter_prescriptions_by_regimen(prescriptions, '0P')
        cohort_struct.zero_a            = filter_prescriptions_by_regimen(prescriptions, '0A')
        cohort_struct.two_p             = filter_prescriptions_by_regimen(prescriptions, '2P')
        cohort_struct.two_a             = filter_prescriptions_by_regimen(prescriptions, '2A')
        cohort_struct.four_a            = filter_prescriptions_by_regimen(prescriptions, '4A')
        cohort_struct.four_pp           = filter_prescriptions_by_regimen(prescriptions, '4PP')
        cohort_struct.four_pa           = filter_prescriptions_by_regimen(prescriptions, '4PA')
        cohort_struct.five_a            = filter_prescriptions_by_regimen(prescriptions, '5A')
        cohort_struct.six_a             = filter_prescriptions_by_regimen(prescriptions, '6A')
        cohort_struct.seven_a           = filter_prescriptions_by_regimen(prescriptions, '7A')
        cohort_struct.eight_a           = filter_prescriptions_by_regimen(prescriptions, '8A')
        cohort_struct.nine_a            = filter_prescriptions_by_regimen(prescriptions, '9A')
        cohort_struct.nine_pp           = filter_prescriptions_by_regimen(prescriptions, '9PP')
        cohort_struct.nine_pa           = filter_prescriptions_by_regimen(prescriptions, '9PA')
        cohort_struct.ten_a             = filter_prescriptions_by_regimen(prescriptions, '10A')
        cohort_struct.eleven_a          = filter_prescriptions_by_regimen(prescriptions, '11A')
        cohort_struct.eleven_pp         = filter_prescriptions_by_regimen(prescriptions, '11PP')
        cohort_struct.eleven_pa         = filter_prescriptions_by_regimen(prescriptions, '11PA')
        cohort_struct.twelve_a          = filter_prescriptions_by_regimen(prescriptions, '12A')
        cohort_struct.twelve_pp         = filter_prescriptions_by_regimen(prescriptions, '12PP')
        cohort_struct.twelve_pa         = filter_prescriptions_by_regimen(prescriptions, '12PA')
        cohort_struct.thirteen_a        = filter_prescriptions_by_regimen(prescriptions, '13A')
        cohort_struct.fourteen_pp       = filter_prescriptions_by_regimen(prescriptions, '14PP')
        cohort_struct.fourteen_pa       = filter_prescriptions_by_regimen(prescriptions, '14PA')
        cohort_struct.fourteen_a        = filter_prescriptions_by_regimen(prescriptions, '14A')
        cohort_struct.fifteen_p         = filter_prescriptions_by_regimen(prescriptions, '15P')
        cohort_struct.fifteen_pp        = filter_prescriptions_by_regimen(prescriptions, '15PP')
        cohort_struct.fifteen_pa        = filter_prescriptions_by_regimen(prescriptions, '15PA')
        cohort_struct.fifteen_a         = filter_prescriptions_by_regimen(prescriptions, '15A')
        cohort_struct.sixteen_p         = filter_prescriptions_by_regimen(prescriptions, '16P')
        cohort_struct.sixteen_a         = filter_prescriptions_by_regimen(prescriptions, '16A')
        cohort_struct.seventeen_pp      = filter_prescriptions_by_regimen(prescriptions, '17PP')
        cohort_struct.seventeen_pa      = filter_prescriptions_by_regimen(prescriptions, '17PA')
        cohort_struct.seventeen_a       = filter_prescriptions_by_regimen(prescriptions, '17A')
        cohort_struct.unknown_regimen   = filter_prescriptions_by_regimen(prescriptions, 'unknown_regimen')

        # Total patients with side effects:
        # Alive and On ART patients with DRUG INDUCED observations during their last HIV CLINIC CONSULTATION encounter up to the reporting period

        with_se, without_se, se_unknowns = patients_side_effects_status(cohort_struct.total_alive_and_on_art, end_date)
        cohort_struct.total_patients_with_side_effects = with_se
        cohort_struct.total_patients_without_side_effects = without_se
        cohort_struct.unknown_side_effects = se_unknowns

        CohortProgress.step!(progress_key, :side_effects) if progress_key
        # TB Status
        # Alive and On ART with 'TB Status' observation value of 'TB not Suspected' or 'TB Suspected'
        # or 'TB confirmed and on Treatment', or 'TB confirmed and not on Treatment' or 'Unknown TB status'
        # during their latest HIV Clinic Consultaiton encounter in the reporting period
        write_tb_status_indicators(cohort_struct, cohort_struct.total_alive_and_on_art, start_date, end_date)

        # ART adherence
        #
        # Alive and On ART with value of their 'Drug order adherence" observation during their latest Adherence
        # encounter in the reporting period  between 95 and 105
        adherent, not_adherent, unknown_adherence = latest_art_adherence(cohort_struct.total_alive_and_on_art,
                                                                         start_date, end_date)
        cohort_struct.patients_with_0_6_doses_missed_at_their_last_visit = adherent
        cohort_struct.patients_with_7_plus_doses_missed_at_their_last_visit = not_adherent
        cohort_struct.patients_with_unknown_adhrence = unknown_adherence

        CohortProgress.step!(progress_key, :adherence) if progress_key

        # Pregnant and breastfeeding status during Consultation.
        # total_pregnant_women joins @obs_last_visit_thread internally (waits for preload).
        # Start CPT and IPT order-scans in background threads so they run while we wait.
        cpt_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            total_patients_on_arvs_and_cpt(cohort_struct.total_alive_and_on_art, start_date, end_date)
          end
        end
        ipt_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            total_patients_on_arvs_and_ipt(cohort_struct.total_alive_and_on_art, start_date, end_date)
          end
        end

        cohort_struct.total_pregnant_women = total_pregnant_women(cohort_struct.total_alive_and_on_art, start_date,
                                                                  end_date)
        cohort_struct.total_breastfeeding_women = total_breastfeeding_women(cohort_struct.total_alive_and_on_art,
                                                                            cohort_struct.total_pregnant_women, start_date, end_date)
        cohort_struct.total_other_patients = total_other_patients(cohort_struct.total_alive_and_on_art,
                                                                  cohort_struct.total_breastfeeding_women, cohort_struct.total_pregnant_women)

        CohortProgress.step!(progress_key, :preg_bf) if progress_key
        # Collect CPT/IPT results (threads started before the obs_last_visit join-wait above)
        cohort_struct.total_patients_on_arvs_and_cpt = cpt_thread.value
        cohort_struct.total_patients_on_arvs_and_ipt = ipt_thread.value

        CohortProgress.step!(progress_key, :tpt_fp_bp) if progress_key
        # Family planning and BP screening — run in parallel (obs-based, independent date ranges)
        fp_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            total_patients_on_family_planning(cohort_struct.total_alive_and_on_art, quarter_start_date, end_date)
          end
        end
        bp_patients_over_30 = total_patients_alive_and_on_art_above_30_years(cohort_struct.total_alive_and_on_art,
                                                                             end_date)
        bp_thread = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            total_patients_with_screened_bp(bp_patients_over_30, start_date, end_date)
          end
        end
        cohort_struct.total_patients_on_family_planning = fp_thread.value
        cohort_struct.total_patients_with_screened_bp   = bp_thread.value

        # Patients who started TPT in current reporting period
        # (pre-fetched in tpt_thread running concurrently with update_cum_outcome)
        tpt_results = tpt_thread.value
        cohort_struct.newly_initiated_on_3hp = tpt_results[:tpt_3hp].select do |hash|
          hash['last_tpt_start_date'].nil?
        end
        cohort_struct.newly_initiated_on_ipt = tpt_results[:tpt_ipt].select do |hash|
          hash['last_tpt_start_date'].nil?
        end

        time_ended = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        puts "Started at: #{time_started}. Finished at: #{time_ended}. Total time in minutes: #{(Time.parse(time_ended) - Time.parse(time_started)) / 60}"
        Rails.logger.info "Started at: #{time_started}. Finished at: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}. Total time in minutes: #{(Time.parse(time_ended) - Time.parse(time_started)) / 60}"
        cohort_struct
      end

      # private

      def get_disaggregated_cohort(start_date, end_date, gender, ag)
        case ag
        when '50+ years'
          diff = [50, 1000]
          iu = 'year'
        when /years/i
          diff = ag.sub(' years', '').split('-')
          iu = 'year'
        when /months/i
          diff = ag.sub(' months', '').split('-')
          iu = 'month'
        else
          case gender
          when 'M'
            diff = [0, 1000]
            iu = 'year'
            gender = 'M'
          when 'FNP'
            diff = [0, 1000]
            iu = 'year'
            gender = 'F'
          when 'FP'
            diff = [0, 1000]
            iu = 'year'
            gender = 'F'
          when 'FBf'
            diff = [0, 1000]
            iu = 'year'
            gender = 'F'
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
            AND moh_cum_outcome = 'On antiretrovirals'
            AND timestampdiff(#{iu}, birthdate, date_enrolled) BETWEEN #{diff[0].to_i} AND #{diff[1].to_i}"
        )

        EncounterType.find_by_name('DISPENSING').id
        amount_dispensed = concept('Amount dispensed').concept_id
        ipt_drug_ids = Drug.find_all_by_concept_id(656).map(&:drug_id)

        patient_ids = []
        (data1 || {}).each_key do |x|
          patient_ids << x['patient_id'].to_i
        end

        unless patient_ids.blank?
          data2 = ActiveRecord::Base.connection.select_all(
            "SELECT e.patient_id FROM encounter e
            INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
              AND o.moh_cum_outcome = 'On antiretrovirals' INNER JOIN obs ON obs.encounter_id = e.encounter_id
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

        start_date.to_date
        end_date.to_date

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
            "SELECT e.*, moh_cum_outcome, patient_reason_for_starting_art_text(e.patient_id) reason_for_starting
            FROM temp_patient_outcomes o
            INNER JOIN temp_earliest_start_date e ON e.patient_id = o.patient_id
            WHERE moh_cum_outcome LIKE '%Pre-%' OR moh_cum_outcome LIKE '%Unknown%'"
          )
        rescue StandardError
          raise 'Try running the revised cohort before this report'
        end

        data = {}

        (patients || []).each do |p|
          Patient.find(p['patient_id'].to_i)

          patient_outcome = p['moh_cum_outcome']
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

      def load_data_into_temp_earliest_start_date(end_date, occupation = nil)
        load_data_into_temp_cohort_members_table(end_date)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_earliest_start_date
          SELECT patient_id, date_enrolled, earliest_start_date, recorded_start_date, birthdate, birthdate_estimated, death_date, gender, age_at_initiation, age_in_days, reason_for_starting_art, earliest_start_date_by_enrollment
          FROM temp_cohort_members #{occupation_filter(occupation:, field_name: 'occupation')}
        SQL
      end

      # rubocop:disable Metrics/MethodLength
      def load_data_into_temp_cohort_members_table(end_date)
        end_date = ActiveRecord::Base.connection.quote(end_date)

        type_of_patient_concept = concept('Type of patient').concept_id
        new_patient_concept = concept('New patient').concept_id
        drug_refill_concept = concept('Drug refill').concept_id
        external_concept = concept('External Consultation').concept_id
        program_id = Program.find_by(name: 'HIV program').id

        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_cohort_members
          SELECT patient_program.patient_id,
                 DATE(MIN(art_order.start_date)) AS date_enrolled,
                 DATE(COALESCE(MIN(art_start_date_obs.value_datetime), MIN(art_order.start_date))) AS earliest_start_date,
                 DATE(MIN(art_start_date_obs.value_datetime)) AS recorded_start_date,
                 person.birthdate,
                 person.birthdate_estimated,
                 person.death_date,
                 LEFT(person.gender, 1) gender,
                 IF(person.birthdate IS NOT NULL, TIMESTAMPDIFF(YEAR, person.birthdate,  DATE(COALESCE(art_start_date_obs.value_datetime, MIN(art_order.start_date)))), NULL) AS age_at_initiation,
                 IF(person.birthdate IS NOT NULL, TIMESTAMPDIFF(DAY, person.birthdate,  DATE(COALESCE(art_start_date_obs.value_datetime, MIN(art_order.start_date)))), NULL) AS age_in_days,
                 rfsa.reason_for_starting_art,
                 pa.value AS occupation,
                 tasdbe.earliest_start_date_by_enrollment
          FROM patient_program
          INNER JOIN person ON person.person_id = patient_program.patient_id AND person.voided = 0
          LEFT JOIN (#{current_occupation_query}) pa ON pa.person_id = patient_program.patient_id
          LEFT JOIN patient_state AS outcome
            ON outcome.patient_program_id = patient_program.patient_program_id
          LEFT JOIN temp_art_start_date AS art_start_date_obs
            ON art_start_date_obs.patient_id = patient_program.patient_id
          LEFT JOIN temp_reason_for_starting_art AS rfsa
            ON rfsa.patient_id = patient_program.patient_id
          LEFT JOIN temp_art_start_date_by_enrollment AS tasdbe
            ON tasdbe.patient_id = patient_program.patient_id
           /* TODO: Re-enable the following condition. Has been removed because LLH and PIH
              were noted to be dropping patients because of it. Seems these sites may have orders
              without corresponding encounters. Adding this condition bumps up performance a bit. */
           /* INNER JOIN encounter AS prescription_encounter
            ON prescription_encounter.patient_id = patient_program.patient_id
            AND prescription_encounter.program_id = patient_program.program_id
            AND prescription_encounter.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
            AND prescription_encounter.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name LIKE 'Treatment')
            AND prescription_encounter.voided = 0 */
          INNER JOIN temp_order_details AS art_order ON art_order.patient_id = patient_program.patient_id AND art_order.start_date <= DATE(#{end_date})
          WHERE patient_program.voided = 0
            AND outcome.voided = 0
            AND patient_program.program_id = 1
            AND outcome.state = 7
            AND outcome.start_date IS NOT NULL
            /*AND patient_program.patient_id NOT IN (
              SELECT e.patient_id FROM encounter e
              LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{new_patient_concept}) AS new_patient ON e.patient_id = new_patient.person_id
              LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{drug_refill_concept}) AS refill ON e.patient_id = refill.person_id
              LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{external_concept}) AS external ON e.patient_id = external.person_id
              WHERE e.program_id = #{program_id} AND (refill.value_coded IS NOT NULL OR external.value_coded IS NOT NULL)
              AND new_patient.value_coded IS NULL
              AND e.encounter_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
              AND e.encounter_type IN (SELECT encounter_type_id FROM encounter_type WHERE name = 'REGISTRATION' AND retired = 0)
              GROUP BY e.patient_id
            )*/
          GROUP by patient_program.patient_id HAVING reason_for_starting_art IS NOT NULL
        SQL
        remove_drug_refills_and_external_consultation(end_date)
      end
      # rubocop:enable Metrics/MethodLength

      def load_temp_other_patient_types(end_date)
        type_of_patient_concept = concept('Type of patient').concept_id
        drug_refill_concept = concept('Drug refill').concept_id
        external_concept = concept('External Consultation').concept_id

        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_other_patient_types (patient_id)
          SELECT pp.patient_id as patient_id
          FROM patient_program pp
          INNER JOIN obs o ON pp.patient_id = o.person_id AND o.concept_id = #{type_of_patient_concept}
          AND o.value_coded IN (#{drug_refill_concept},#{external_concept})
          AND o.voided = 0
          AND o.obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
          WHERE pp.program_id = 1
          AND pp.voided = 0
          GROUP BY patient_id
        SQL
      end

      # Runs Phase 1 temp-table loading in parallel threads.
      # Dependency: load_temp_order_details reads temp_register_start_date, so it is
      # chained in the same thread as load_temp_register_start_date_table.
      # All other loaders are fully independent of each other.
      # Each thread checks out its own DB connection from the pool.
      def load_phase1_parallel(end_date)
        threads = []

        # Thread 1: other_patient_types first, then register_start_date (depends on it), then order_details (depends on register_start_date)
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            load_temp_other_patient_types(end_date)
            load_temp_register_start_date_table(end_date)
            load_temp_order_details(end_date)
          end
        end

        # Thread 2-4: fully independent
        threads << Thread.new { ActiveRecord::Base.connection_pool.with_connection { load_art_start_date(end_date) } }
        threads << Thread.new { ActiveRecord::Base.connection_pool.with_connection { load_temp_reason_for_starting_art(end_date) } }
        threads << Thread.new { ActiveRecord::Base.connection_pool.with_connection { load_temp_art_start_date_by_enrollment(end_date) } }

        threads.each(&:join)
      end

      def load_temp_order_details(end_date)
        # FORCE INDEX (idx_orders_type_voided_start_patient) makes MySQL start from the
        # composite index on (order_type_id, voided, start_date, patient_id) rather than
        # the default plan that starts from arv_drug → drug → drug_order → orders(PRIMARY),
        # which requires ~800K random PK lookups. The forced plan does a sequential range
        # scan on the index and then joins outward. Measured improvement: 75s → 23s cold.
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_order_details
          SELECT o.patient_id, DATE(MIN(o.start_date)) start_date
          FROM orders o FORCE INDEX (idx_orders_type_voided_start_patient)
          INNER JOIN drug_order do ON do.order_id = o.order_id AND do.quantity > 0
          INNER JOIN arv_drug ad ON ad.drug_id = do.drug_inventory_id
          LEFT JOIN temp_register_start_date trsd ON trsd.patient_id = o.patient_id
          WHERE o.order_type_id = 1
            AND o.voided = 0
            AND o.start_date < DATE('#{end_date}') + INTERVAL 1 DAY
            AND o.start_date >= COALESCE(trsd.start_date, DATE('1901-01-01'))
          GROUP BY o.patient_id;
        SQL
      end

      def load_art_start_date(end_date)
        # Drive from obs via idx_obs_art_start_date_lookup (concept_id, voided, value_datetime, person_id)
        # — a covering range scan at <1 second — then join to encounter by PK (~18K PK lookups).
        # The original code drove FROM encounter → obs (encounter_type=9 filter first), costing
        # ~43s because MySQL scanned all encounter rows and then did per-row obs bookmark lookups.
        # By inverting the driver (obs first, then encounter PK join) we keep the HIV CLINIC
        # REGISTRATION + program_id = 1 correctness filter while remaining fast.
        ActiveRecord::Base.connection.execute <<-SQL
          INSERT INTO temp_art_start_date
          SELECT o.person_id, DATE(MIN(o.value_datetime)) value_datetime
          FROM obs o FORCE INDEX (idx_obs_art_start_date_lookup)
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id
            AND e.encounter_type = 9
            AND e.program_id = 1
            AND e.voided = 0
            AND e.encounter_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
          WHERE o.concept_id = 2516
            AND o.obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
          GROUP BY o.person_id
          HAVING value_datetime IS NOT NULL
        SQL
      end

      def load_temp_register_start_date_table(end_date)
        type_of_patient_concept = concept('Type of patient').concept_id
        new_patient_concept = concept('New patient').concept_id

        ActiveRecord::Base.connection.execute <<-SQL
          INSERT INTO temp_register_start_date (patient_id, start_date)
          SELECT pp.patient_id as patient_id, MIN(o.obs_datetime) AS start_date
          FROM patient_program pp
          INNER JOIN temp_other_patient_types tmp ON tmp.patient_id = pp.patient_id
          INNER JOIN obs o ON pp.patient_id = o.person_id AND o.concept_id = #{type_of_patient_concept}
          AND o.value_coded = #{new_patient_concept}
          AND o.voided = 0
          AND o.obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
          WHERE pp.program_id = 1
          AND pp.voided = 0
          GROUP BY patient_id
        SQL
      end

      def load_temp_reason_for_starting_art(end_date)
        end_date = ActiveRecord::Base.connection.quote(end_date)

        # Replacing ROW_NUMBER() OVER (ORDER BY obs_datetime DESC, date_created DESC) with a
        # three-step MAX approach. The original window function forced a filesort on date_created
        # (not in any index) over ~94k rows, costing ~106 seconds.
        #
        # Step 1: covering index scan (idx_obs_reason_art_lookup) → per-patient MAX(obs_datetime)
        # Step 2: join back to find obs at that datetime, take MAX(date_created) as tie-breaker.
        #         Matches dev's ORDER BY obs_datetime DESC, date_created DESC LIMIT 1 exactly.
        # Step 3: among obs sharing same (obs_datetime, date_created), take MAX(obs_id) for the
        #         final tie. Then outer PK join (obs_id) → O(1) value_coded lookup.
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_reason_for_starting_art (patient_id, reason_for_starting_art)
          SELECT o.person_id, o.value_coded
          FROM obs o
          INNER JOIN (
            SELECT max_dc.person_id, max_dc.max_obs_datetime, max_dc.max_date_created,
                   MAX(o3.obs_id) AS best_obs_id
            FROM (
              SELECT max_dt.person_id, max_dt.max_obs_datetime,
                     MAX(o2.date_created) AS max_date_created
              FROM (
                SELECT person_id, MAX(obs_datetime) AS max_obs_datetime
                FROM obs FORCE INDEX (idx_obs_reason_art_lookup)
                WHERE concept_id = 7563
                  AND voided = 0
                  AND obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY
                GROUP BY person_id
              ) max_dt
              INNER JOIN obs o2 FORCE INDEX (idx_obs_fast_lookup)
                ON o2.person_id = max_dt.person_id
                AND o2.concept_id = 7563
                AND o2.voided = 0
                AND o2.obs_datetime = max_dt.max_obs_datetime
              GROUP BY max_dt.person_id, max_dt.max_obs_datetime
            ) max_dc
            INNER JOIN obs o3 FORCE INDEX (idx_obs_fast_lookup)
              ON o3.person_id = max_dc.person_id
              AND o3.concept_id = 7563
              AND o3.voided = 0
              AND o3.obs_datetime = max_dc.max_obs_datetime
              AND o3.date_created = max_dc.max_date_created
            GROUP BY max_dc.person_id, max_dc.max_obs_datetime, max_dc.max_date_created
          ) best ON best.best_obs_id = o.obs_id
          WHERE o.concept_id = 7563
            AND o.voided = 0
        SQL
      end

      def load_temp_art_start_date_by_enrollment(end_date)
        arv_concept_id = concept('ANTIRETROVIRAL DRUGS').concept_id
        dispension_concept_id = concept('AMOUNT DISPENSED').concept_id
        art_start_date_concept_id = 2516 # ART start date concept

        # Step 1: Get the recorded ART start dates (value_datetime)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_art_start_date_by_enrollment (patient_id, earliest_start_date_by_enrollment)
          SELECT#{' '}
            person_id AS patient_id,
            DATE(MIN(value_datetime)) AS earliest_start_date_by_enrollment
          FROM obs#{' '}
          WHERE concept_id = #{art_start_date_concept_id}
            AND encounter_id > 0
            AND value_datetime IS NOT NULL
            AND value_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            AND voided = 0
          GROUP BY person_id
        SQL

        # Step 2: Handle estimated dates (value_text with durations)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT IGNORE INTO temp_art_start_date_by_enrollment (patient_id, earliest_start_date_by_enrollment)
          SELECT#{' '}
            person_id AS patient_id,
            CASE#{' '}
              WHEN value_text = '6 months' THEN DATE_SUB(obs_datetime, INTERVAL 6 MONTH)
              WHEN value_text = '12 months' THEN DATE_SUB(obs_datetime, INTERVAL 12 MONTH)
              WHEN value_text = '18 months' THEN DATE_SUB(obs_datetime, INTERVAL 18 MONTH)
              WHEN value_text = '24 months' THEN DATE_SUB(obs_datetime, INTERVAL 24 MONTH)
              WHEN value_text = '48 months' THEN DATE_SUB(obs_datetime, INTERVAL 48 MONTH)
              WHEN value_text = 'Over 2 years' THEN DATE_SUB(obs_datetime, INTERVAL 60 MONTH)
              ELSE NULL
            END AS earliest_start_date_by_enrollment
          FROM obs
          WHERE concept_id = #{art_start_date_concept_id}
            AND encounter_id > 0
            AND value_text IS NOT NULL
            AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            AND voided = 0
          GROUP BY person_id
          HAVING earliest_start_date_by_enrollment IS NOT NULL
        SQL

        # Step 3: Fallback to earliest ARV dispensation (patient_start_date logic)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT IGNORE INTO temp_art_start_date_by_enrollment (patient_id, earliest_start_date_by_enrollment)
          SELECT#{' '}
            o.person_id AS patient_id,
            DATE(MIN(o.obs_datetime)) AS earliest_start_date_by_enrollment
          FROM obs o
          INNER JOIN drug d ON o.value_drug = d.drug_id
          INNER JOIN concept_set cs ON d.concept_id = cs.concept_id
          WHERE o.concept_id = #{dispension_concept_id}
            AND cs.concept_set = #{arv_concept_id}
            AND o.obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY
            AND o.voided = 0
          GROUP BY o.person_id
        SQL
      end

      def remove_drug_refills_and_external_consultation(end_date)
        ActiveRecord::Base.connection.execute <<~SQL
          DELETE FROM temp_cohort_members
          WHERE patient_id IN (#{drug_refills_and_external_consultation_list(end_date)})
        SQL
      end

      # this just gives all clients who are truly external or drug refill
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def drug_refills_and_external_consultation_list(end_date)
        to_remove = [0]

        type_of_patient_concept = concept('Type of patient').concept_id
        new_patient_concept = concept('New patient').concept_id
        drug_refill_concept = concept('Drug refill').concept_id
        external_concept = concept('External Consultation').concept_id
        hiv_clinic_registration_id = EncounterType.find_by_name('HIV CLINIC REGISTRATION').encounter_type_id

        ActiveRecord::Base.connection.select_all("SELECT e.patient_id FROM temp_cohort_members e
        LEFT JOIN encounter as hiv_registration ON hiv_registration.patient_id = e.patient_id AND hiv_registration.encounter_datetime < DATE(#{end_date}) AND hiv_registration.encounter_type = #{hiv_clinic_registration_id} AND hiv_registration.voided = 0
        LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{new_patient_concept} AND obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY) AS new_patient ON e.patient_id = new_patient.person_id
        LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{drug_refill_concept} AND obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY) AS refill ON e.patient_id = refill.person_id
        LEFT JOIN (SELECT * FROM obs WHERE concept_id = #{type_of_patient_concept} AND voided = 0 AND value_coded = #{external_concept} AND obs_datetime < DATE(#{end_date}) + INTERVAL 1 DAY) AS external ON e.patient_id = external.person_id
        WHERE (refill.value_coded IS NOT NULL OR external.value_coded IS NOT NULL)
        AND NOT (hiv_registration.encounter_id IS NOT NULL OR new_patient.value_coded IS NOT NULL)
        GROUP BY e.patient_id
        ORDER BY hiv_registration.encounter_datetime DESC, refill.obs_datetime DESC, external.obs_datetime DESC;").each do |record|
          to_remove << record['patient_id'].to_i
        end
        to_remove.join(',')
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize

      def update_cum_outcome(start_date:, end_date:)
        ArtService::Reports::Cohort::Outcomes.new(end_date:, start_date:,
                                                  definition: @outcomes_definition,
                                                  rebuild: 'true').update_cummulative_outcomes
        ArtService::Reports::MaternalStatus.new(end_date:, start_date:).process_data
      end

      def update_tb_status(end_date)
        load_temp_latest_tb_status(end_date)

        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_patient_tb_status
          SELECT e.person_id, obs.value_coded
          FROM temp_latest_tb_status e
          INNER JOIN obs ON obs.person_id = e.person_id AND obs.voided = 0 AND obs.concept_id = 7459 AND obs.obs_datetime = e.obs_datetime
          GROUP BY e.person_id;
        SQL
      end

      def update_patient_side_effects(end_date)
        Cohort::SideEffects.update_side_effects(end_date)
      end

      private

      def load_temp_latest_tb_status(end_date)
        ActiveRecord::Base.connection.select_all <<~SQL
          INSERT INTO temp_latest_tb_status
          SELECT t.person_id, MAX(t.obs_datetime) obs_datetime
          FROM obs t
          INNER JOIN temp_patient_outcomes o ON o.patient_id = t.person_id AND o.moh_cum_outcome = 'On antiretrovirals'
          WHERE t.concept_id = 7459 AND t.voided = 0 AND t.obs_datetime <= '#{end_date} 23:59:59'
          GROUP BY t.person_id
        SQL
      end

      # rubocop:disable Metrics/MethodLength
      def total_patients_with_screened_bp(total_alive_and_on_art, _start_date, end_date)
        return 0 if total_alive_and_on_art.blank? || total_alive_and_on_art.empty?

        bp_concepts = ConceptName.where(name: ['Systolic blood pressure', 'Diastolic blood pressure'])
                                 .select(:concept_id)

        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT person_id
          FROM obs
          WHERE voided = 0
            AND concept_id IN (#{bp_concepts.to_sql})
            AND (value_text IS NOT NULL OR value_numeric IS NOT NULL)
            AND obs_datetime < DATE('#{end_date}') + INTERVAL 1 DAY AND obs_datetime >= DATE('#{end_date}') - INTERVAL 12 MONTH
            AND person_id IN (#{total_alive_and_on_art.join(',')})
          GROUP BY person_id
        SQL

        ((results.count.to_f / total_alive_and_on_art.count) * 100).to_i
      end
      # rubocop:enable Metrics/MethodLength

      def total_patients_alive_and_on_art_above_30_years(total_alive_and_on_art, end_date)
        return nil if total_alive_and_on_art.blank?
        return nil if total_alive_and_on_art.empty?

        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT tesd.patient_id, TIMESTAMPDIFF(YEAR, tesd.birthdate, DATE('#{end_date}')) AS age
          FROM temp_earliest_start_date tesd
          WHERE tesd.patient_id IN (#{total_alive_and_on_art.map { |r| r['patient_id'].to_i }.join(',')})
          GROUP BY tesd.patient_id HAVING age >= 30
        SQL

        # map the results to patient ids
        results&.map { |r| r['patient_id'].to_i }
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      def total_patients_on_family_planning(patients_list, start_date, end_date)
        patient_ids = []
        patient_list = []

        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        all_women = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT * FROM temp_earliest_start_date
          WHERE (gender = 'F' OR gender = 'Female') AND patient_id IN  (#{patient_ids.join(',')})
          AND date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
          GROUP BY patient_id
        SQL

        (all_women || []).each do |patient|
          patient_list << patient['patient_id'].to_i
        end

        return 0 if patient_list.blank?

        hiv_clinic_consultation_encounter_type_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').encounter_type_id
        method_of_family_planning_concept_id = concept('Method of family planning').concept_id
        family_planning_action_to_take_concept_id = concept('Family planning, action to take').concept_id
        none_concept_id = [concept('None').concept_id, concept('No').concept_id]

        # Pre-aggregate max obs date per person as a derived table to eliminate the
        # correlated subquery (previously O(n) lookups) and avoid DATE() on the indexed
        # obs_datetime column. The derived table is computed once and then joined.
        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT o.person_id
          FROM obs o
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id
            AND e.encounter_type = #{hiv_clinic_consultation_encounter_type_id} AND e.voided = 0
            AND e.patient_id IN (#{patient_list.join(',')})
          INNER JOIN (
            SELECT person_id, MAX(DATE(obs_datetime)) AS max_obs_date
            FROM obs
            WHERE voided = 0
              AND concept_id IN (#{family_planning_action_to_take_concept_id}, #{method_of_family_planning_concept_id})
              AND obs_datetime >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
              AND obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            GROUP BY person_id
          ) max_fp ON max_fp.person_id = o.person_id
            AND DATE(o.obs_datetime) = max_fp.max_obs_date
          WHERE o.voided = 0
          AND o.concept_id IN (#{family_planning_action_to_take_concept_id}, #{method_of_family_planning_concept_id})
          AND o.value_coded NOT IN (#{none_concept_id.join(',')})
          AND o.person_id IN (#{patient_list.join(',')})
          AND o.obs_datetime >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
          AND o.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          GROUP BY o.person_id
        SQL

        begin
          ((results.count.to_f / patient_list.count) * 100).to_i
        rescue StandardError
          0
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def total_patients_on_arvs_and_ipt(patients_list, start_date, end_date)
        isoniazid_concept_id = concept('Isoniazid').concept_id
        pyridoxine_concept_id = concept('Pyridoxine').concept_id

        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        # Drive from temp_patient_outcomes (indexed patient_id PK) rather than
        # passing a huge IN list — avoids range-scan + IN-filter on 394K IPT rows.
        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT ods.patient_id
          FROM temp_patient_outcomes tpo
          INNER JOIN orders ods FORCE INDEX (idx_orders_concept_voided_patient_start)
            ON ods.patient_id = tpo.patient_id
            AND ods.voided = 0
            AND ods.concept_id IN (#{isoniazid_concept_id}, #{pyridoxine_concept_id})
            AND ods.start_date >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND ods.start_date <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          INNER JOIN drug_order dos ON dos.order_id = ods.order_id AND dos.quantity > 0
          WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
          GROUP BY ods.patient_id
        SQL

        ((results.count.to_f / patient_ids.count) * 100).to_i
      end

      def total_patients_on_arvs_and_cpt(patients_list, start_date, end_date)
        cpt_concept_id = concept('Cotrimoxazole').concept_id

        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        results = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT ods.patient_id
          FROM temp_patient_outcomes tpo
          INNER JOIN orders ods FORCE INDEX (idx_orders_concept_voided_patient_start)
            ON ods.patient_id = tpo.patient_id
            AND ods.voided = 0
            AND ods.concept_id = #{cpt_concept_id}
            AND ods.start_date >= '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
            AND ods.start_date <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          INNER JOIN drug_order dos ON dos.order_id = ods.order_id AND dos.quantity > 0
          WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
          GROUP BY ods.patient_id
        SQL

        ((results.count.to_f / patient_ids.count) * 100).to_i
      end

      def total_breastfeeding_women(_patients_list, total_pregnant_women, _start_date, _end_date)
        pregnant_ids = if total_pregnant_women.empty?
                         [0]
                       else
                         total_pregnant_women.map { |woman| woman['person_id'].to_i }
                       end

        if @obs_last_visit_thread
          # Thread already joined (and temp_obs_last_visit populated) by total_pregnant_women.
          breastfeeding_concept_ids = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                                 .pluck(:concept_id)
          return [] if breastfeeding_concept_ids.empty?

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT t.patient_id AS person_id, t.value_coded
            FROM temp_obs_last_visit t
            WHERE t.concept_id IN (#{breastfeeding_concept_ids.join(',')})
              AND t.patient_id NOT IN (#{pregnant_ids.join(',')})
          SQL
        else
          encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                         .select(:encounter_type_id)
          breastfeeding_concepts = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                              .select(:concept_id)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tpo.patient_id AS person_id, obs.value_coded
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date e
              ON e.patient_id = tpo.patient_id
              AND LEFT(e.gender, 1) = 'F'
              AND e.patient_id NOT IN (#{pregnant_ids.join(',')})
            INNER JOIN temp_max_drug_orders max_obs ON max_obs.patient_id = tpo.patient_id
            INNER JOIN obs FORCE INDEX (idx_obs_fast_lookup) ON obs.person_id = tpo.patient_id
              AND obs.voided = 0
              AND obs.concept_id IN (#{breastfeeding_concepts.to_sql})
              AND obs.value_coded = 1065
              AND obs.obs_datetime >= DATE(max_obs.start_date)
              AND obs.obs_datetime < DATE(max_obs.start_date) + INTERVAL 1 DAY
            INNER JOIN encounter enc
              ON enc.encounter_id = obs.encounter_id
              AND enc.voided = 0
              AND enc.encounter_type IN (#{encounter_types.to_sql})
            WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
            GROUP BY tpo.patient_id
          SQL
        end
      end

      def total_pregnant_women(_patients_list, _start_date, _end_date)
        # Wait for the background pre-load thread (started alongside adherence preload).
        # On success, query the tiny temp_obs_last_visit table (~ms).
        # On failure, fall back to the original per-patient obs scan.
        if @obs_last_visit_thread
          begin
            @obs_last_visit_thread.join
          rescue StandardError => e
            Rails.logger.warn("obs_last_visit preload failed (#{e.message}); falling back to obs scan")
            @obs_last_visit_thread = nil
          end
        end

        if @obs_last_visit_thread
          pregnant_concept_ids = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                            .pluck(:concept_id)
          return [] if pregnant_concept_ids.empty?

          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT t.patient_id AS person_id, t.value_coded
            FROM temp_obs_last_visit t
            WHERE t.concept_id IN (#{pregnant_concept_ids.join(',')})
          SQL
        else
          encounter_types = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                         .select(:encounter_type_id)
          pregnant_concepts = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                         .select(:concept_id)
          ActiveRecord::Base.connection.select_all <<~SQL
            SELECT tpo.patient_id AS person_id, obs.value_coded
            FROM temp_patient_outcomes tpo
            INNER JOIN temp_earliest_start_date e
              ON e.patient_id = tpo.patient_id
              AND LEFT(e.gender, 1) = 'F'
            INNER JOIN temp_max_drug_orders max_obs ON max_obs.patient_id = tpo.patient_id
            INNER JOIN obs FORCE INDEX (idx_obs_fast_lookup) ON obs.person_id = tpo.patient_id
              AND obs.voided = 0
              AND obs.concept_id IN (#{pregnant_concepts.to_sql})
              AND obs.value_coded = 1065
              AND obs.obs_datetime >= DATE(max_obs.start_date)
              AND obs.obs_datetime < DATE(max_obs.start_date) + INTERVAL 1 DAY
            INNER JOIN encounter enc
              ON enc.encounter_id = obs.encounter_id
              AND enc.voided = 0
              AND enc.encounter_type IN (#{encounter_types.to_sql})
            WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
            GROUP BY tpo.patient_id
          SQL
        end
      end

      def total_other_patients(patient_list, all_breastfeeding_women, all_pregnant_women)
        patient_ids = []
        all_pregnant_women_ids = []
        all_breastfeeding_women_ids = []

        (patient_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        (all_pregnant_women || []).each do |row|
          all_pregnant_women_ids << row['person_id'].to_i
        end

        (all_breastfeeding_women || []).each do |row|
          all_breastfeeding_women_ids << row['person_id'].to_i
        end

        (patient_ids - (all_breastfeeding_women_ids + all_pregnant_women_ids))
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

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
      def latest_art_adherence(patients_alive_and_on_art, _start_date, end_date)
        patients_alive_and_on_art = Set.new(patients_alive_and_on_art.map { |patient| patient['patient_id'] })
        return [[], [], patients_alive_and_on_art] if patients_alive_and_on_art.empty?

        end_date = ActiveRecord::Base.connection.quote(end_date)

        # Join the background pre-load started by build() if available, otherwise load inline.
        if @adherence_preload_thread
          @adherence_preload_thread.join
          @adherence_preload_thread = nil
        else
          load_tmp_max_adherence(end_date)
        end

        # Two-query approach: not_adherent first (priority over adherent), then adherent.
        # Drive from tmp_max_adherence (25K patients) → obs via idx_obs_fast_lookup.
        # Matches dev's correctness: a patient with any non-adherent obs is not_adherent,
        # even if they also have an adherent obs at the same visit.
        not_adherent = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT adherence.person_id
          FROM tmp_max_adherence AS max_adherence
          INNER JOIN obs AS adherence FORCE INDEX (idx_obs_fast_lookup)
            ON adherence.person_id = max_adherence.person_id
            AND adherence.concept_id = #{drug_order_adherence_concept.concept_id}
            AND adherence.voided = 0
            AND adherence.obs_datetime >= max_adherence.visit_date
            AND adherence.obs_datetime < (max_adherence.visit_date + INTERVAL 1 DAY)
          INNER JOIN orders
            ON orders.order_id = adherence.order_id
            AND orders.order_type_id = #{drug_order_type.order_type_id}
            AND orders.voided = 0
          INNER JOIN (SELECT concept_id FROM concept_set WHERE concept_set = 1085) AS arv_concepts
            ON arv_concepts.concept_id = orders.concept_id
          WHERE ((adherence.value_numeric < #{MIN_ART_ADHERENCE_THRESHOLD}
                  OR adherence.value_numeric > #{MAX_ART_ADHERENCE_THRESHOLD})
                 OR (CAST(adherence.value_text AS SIGNED INTEGER) < #{MIN_ART_ADHERENCE_THRESHOLD}
                     OR CAST(adherence.value_text AS SIGNED INTEGER) > #{MAX_ART_ADHERENCE_THRESHOLD}))
            AND adherence.voided = 0
          GROUP BY adherence.person_id
        SQL

        not_adherent_ids = not_adherent.empty? ? [] : not_adherent.map { |row| row['person_id'] }

        adherent = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT adherence.person_id
          FROM tmp_max_adherence AS max_adherence
          INNER JOIN obs AS adherence FORCE INDEX (idx_obs_fast_lookup)
            ON adherence.person_id = max_adherence.person_id
            AND adherence.concept_id = #{drug_order_adherence_concept.concept_id}
            AND adherence.voided = 0
            AND adherence.obs_datetime >= max_adherence.visit_date
            AND adherence.obs_datetime < (max_adherence.visit_date + INTERVAL 1 DAY)
            AND max_adherence.person_id NOT IN (#{not_adherent_ids.empty? ? 0 : not_adherent_ids.join(',')})
          INNER JOIN orders
            ON orders.order_id = adherence.order_id
            AND orders.order_type_id = #{drug_order_type.order_type_id}
            AND orders.voided = 0
          INNER JOIN (SELECT concept_id FROM concept_set WHERE concept_set = 1085) AS arv_concepts
            ON arv_concepts.concept_id = orders.concept_id
          WHERE ((adherence.value_numeric >= #{MIN_ART_ADHERENCE_THRESHOLD}
                  AND adherence.value_numeric <= #{MAX_ART_ADHERENCE_THRESHOLD})
                 OR (CAST(adherence.value_text AS SIGNED INTEGER) >= #{MIN_ART_ADHERENCE_THRESHOLD}
                     AND CAST(adherence.value_text AS SIGNED INTEGER) <= #{MAX_ART_ADHERENCE_THRESHOLD}))
            AND adherence.voided = 0
          GROUP BY adherence.person_id
        SQL

        adherent_ids = adherent.map { |row| row['person_id'] }
        unknown_adherence = Set.new(patients_alive_and_on_art) - adherent_ids - not_adherent_ids

        [adherent_ids, not_adherent_ids, unknown_adherence]
      end

      def load_tmp_max_adherence(end_date)
        # Materialize ARV drug concept IDs once — avoids re-evaluating the subquery per row
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TEMPORARY TABLE IF NOT EXISTS temp_arv_drug_concepts (
            concept_id INT PRIMARY KEY
          ) ENGINE=MEMORY
        SQL
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT IGNORE INTO temp_arv_drug_concepts (concept_id)
          SELECT concept_id FROM concept_set WHERE concept_set = 1085
        SQL

        # Drive from the ~25K active patients and constrain the obs scan to start from each
        # patient's last ARV order date (temp_max_drug_orders.start_date, populated by
        # update_cum_outcome). Adherence obs (concept_id=6987) are recorded at dispensation
        # encounters, so obs_datetime ≈ orders.start_date. Using the last order date as a
        # floor shrinks each patient's obs range from their full ART history (50-100+ rows)
        # to just the last dispensation visit (1-3 rows), cutting scan volume by ~50x.
        #
        # idx_obs_fast_lookup (person_id, concept_id, voided, obs_datetime) turns the
        # constrained range into a tight 2-sided scan per patient.
        #
        # READ UNCOMMITTED prevents InnoDB from acquiring shared next-key locks on every
        # scanned obs/orders row. Under the default REPEATABLE READ isolation, an
        # INSERT INTO ... SELECT locks all source rows it touches; on a large obs table
        # (~millions of rows) this exhausts the InnoDB lock table and raises
        # "The total number of locks exceeds the lock table size". This is a read-only
        # reporting scan on stable data, so dirty-read anomalies cannot occur in practice.
        conn = ActiveRecord::Base.connection
        conn.execute('SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED')
        begin
          conn.execute <<~SQL
            INSERT INTO tmp_max_adherence
            SELECT tpo.patient_id, DATE(MAX(obs.obs_datetime)) AS visit_date
              FROM temp_patient_outcomes tpo
              INNER JOIN temp_max_drug_orders mdo ON mdo.patient_id = tpo.patient_id
              INNER JOIN obs FORCE INDEX (idx_obs_fast_lookup)
                ON obs.person_id = tpo.patient_id
                AND obs.concept_id = 6987
                AND obs.voided = 0
                AND obs.obs_datetime >= DATE(mdo.start_date)
                AND obs.obs_datetime < (DATE(#{end_date}) + INTERVAL 1 DAY)
                AND (obs.value_numeric IS NOT NULL OR obs.value_text IS NOT NULL)
              INNER JOIN orders
                ON orders.order_id = obs.order_id
                AND orders.order_type_id = 1
                AND orders.voided = 0
              INNER JOIN temp_arv_drug_concepts
                ON temp_arv_drug_concepts.concept_id = orders.concept_id
              WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
              GROUP BY tpo.patient_id;
          SQL
        ensure
          conn.execute('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ')
        end
      end

      # Pre-load a temp table of observations recorded at each female ART patient's last
      # drug-order visit for pregnant/breastfeeding concepts. Called in a background thread
      # (alongside the adherence preload) so total_pregnant_women and total_breastfeeding_women
      # can answer in milliseconds rather than doing ~7 K per-patient obs lookups each.
      def load_temp_obs_last_visit(_quoted_end_date)
        encounter_type_ids = EncounterType.where(name: ['HIV CLINIC CONSULTATION', 'HIV STAGING'])
                                          .pluck(:encounter_type_id)
        pregnant_concept_ids = ConceptName.where(name: ['Is patient pregnant?', 'patient pregnant'])
                                          .pluck(:concept_id)
        breastfeeding_concept_ids = ConceptName.where(name: ['Breast feeding?', 'Breast feeding', 'Breastfeeding'])
                                               .pluck(:concept_id)

        all_concept_ids = (pregnant_concept_ids + breastfeeding_concept_ids).uniq
        return if all_concept_ids.empty? || encounter_type_ids.empty?

        ActiveRecord::Base.connection.execute 'DROP TABLE IF EXISTS temp_obs_last_visit'
        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_obs_last_visit (
            patient_id  INT NOT NULL,
            concept_id  INT NOT NULL,
            value_coded INT,
            PRIMARY KEY (patient_id, concept_id)
          ) ENGINE=InnoDB
        SQL

        # Drive from each patient's last drug-order visit (temp_max_drug_orders.start_date)
        # rather than a fixed end_date-1year window. Using idx_obs_fast_lookup for a tight
        # per-patient range scan on (person_id, concept_id, voided, obs_datetime) exactly
        # like the dev-branch fallback in total_breastfeeding_women / total_pregnant_women.
        # The 1-year pre-filter caused patients whose last drug order was > 1 year before
        # end_date to be silently excluded.
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_obs_last_visit (patient_id, concept_id, value_coded)
          SELECT tpo.patient_id, obs.concept_id, 1065 AS value_coded
          FROM temp_patient_outcomes tpo
          INNER JOIN temp_earliest_start_date e
            ON e.patient_id = tpo.patient_id
            AND LEFT(e.gender, 1) = 'F'
          INNER JOIN temp_max_drug_orders max_obs ON max_obs.patient_id = tpo.patient_id
          INNER JOIN obs FORCE INDEX (idx_obs_fast_lookup)
            ON obs.person_id = tpo.patient_id
            AND obs.concept_id IN (#{all_concept_ids.join(',')})
            AND obs.voided = 0
            AND obs.value_coded = 1065
            AND obs.obs_datetime >= DATE(max_obs.start_date)
            AND obs.obs_datetime < DATE(max_obs.start_date) + INTERVAL 1 DAY
          INNER JOIN encounter enc
            ON enc.encounter_id = obs.encounter_id
            AND enc.voided = 0
            AND enc.encounter_type IN (#{encounter_type_ids.join(',')})
          WHERE tpo.moh_cum_outcome = 'On antiretrovirals'
          GROUP BY tpo.patient_id, obs.concept_id
        SQL
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

      def write_tb_status_indicators(cohort_struct, _patients_alive_and_on_art, _start_date, end_date)
        cohort_struct.tb_suspected = []
        cohort_struct.tb_not_suspected = []
        cohort_struct.tb_confirmed_on_tb_treatment = []
        cohort_struct.tb_confirmed_currently_not_yet_on_tb_treatment = []
        cohort_struct.unknown_tb_status = []

        tb_suspected_concept = concept('TB Suspected')
        tb_not_suspected_concept = concept('TB Not Suspected')
        tb_confirmed_but_not_on_treatment = concept('Confirmed TB NOT on Treatment')
        tb_confirmed_and_on_treatment = concept('Confirmed TB on Treatment')

        # patients_alive_and_on_art
        (all_tb_statuses(end_date) || []).each do |data|
          tb_status_value = begin
            data['tb_status'].to_i
          rescue StandardError
            nil
          end

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
          WHERE o.moh_cum_outcome = 'On antiretrovirals'
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

      def patients_side_effects_status(_patients_alive_and_on_art, end_date)
        with_side_effects = []
        without_side_effects = []
        unknowns = []

        records = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT e.*, s.has_se
          FROM temp_earliest_start_date e
          INNER JOIN temp_patient_side_effects s ON s.patient_id = e.patient_id
          INNER JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id AND o.moh_cum_outcome = 'On antiretrovirals'
          WHERE DATE(e.date_enrolled) <= '#{end_date.to_date}';
        SQL

        (records || []).each do |data|
          if data['has_se'] == 'Yes'
            with_side_effects << data['patient_id']
          elsif data['has_se'] == 'No'
            without_side_effects << data['patient_id']
          else
            unknowns << data['patient_id']
          end
        end

        [with_side_effects, without_side_effects, unknowns]
      end

      COHORT_REGIMENS = %w[
        0P 2P 4PP 4PA 9PP 9PA 11PP 11PA 12PP 12PA 14PP 14PA 15P 15PP 15PA 16P 17PP 17PA
        4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A 16A 17A
      ].freeze

      def cal_regimem_category(_patient_list, _end_date)
        Cohort::Regimens.patient_regimens.map do |prescription|
          regimen = prescription['regimen_category']

          regimen = 'unknown_regimen' if regimen == 'Unknown' || !COHORT_REGIMENS.include?(regimen)

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

      # Replaces 4 separate calls to the died_in() stored function with one set-based query.
      # The stored function fetches COALESCE(death_date, moh_outcome_date) and runs
      # TIMESTAMPDIFF per row — this inlines that logic using a CASE expression.
      def all_died_in_buckets
        data = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT
            o.patient_id,
            CASE
              WHEN COALESCE(t.death_date, o.moh_outcome_date) IS NULL THEN 'Unknown'
              WHEN TIMESTAMPDIFF(DAY, DATE(t.earliest_start_date), DATE(COALESCE(t.death_date, o.moh_outcome_date))) <= 30  THEN '1st month'
              WHEN TIMESTAMPDIFF(DAY, DATE(t.earliest_start_date), DATE(COALESCE(t.death_date, o.moh_outcome_date))) <= 60  THEN '2nd month'
              WHEN TIMESTAMPDIFF(DAY, DATE(t.earliest_start_date), DATE(COALESCE(t.death_date, o.moh_outcome_date))) <= 91  THEN '3rd month'
              ELSE '4+ months'
            END AS died_in_bucket
          FROM temp_patient_outcomes o
          INNER JOIN temp_earliest_start_date t USING(patient_id)
          WHERE o.moh_cum_outcome = 'Patient died'
          GROUP BY o.patient_id
        SQL

        buckets = Hash.new { |h, k| h[k] = [] }
        (data || []).each do |row|
          bucket = row['died_in_bucket']
          # 'Unknown' maps into the 4+ months bucket to preserve previous behaviour
          bucket = '4+ months' if bucket == 'Unknown'
          buckets[bucket] << row['patient_id']
        end
        buckets
      end

      def died_in(month_str)
        all_died_in_buckets[month_str] || []
      end

      def get_outcome(outcome)
        sql_patch = if outcome == 'Pre-ART (Continue)'
                      "moh_cum_outcome = '#{outcome}' OR moh_cum_outcome = 'Unknown'"
                    else
                      "moh_cum_outcome = '#{outcome}'"
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

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT *
          FROM temp_earliest_start_date t
          INNER JOIN obs ON t.patient_id = obs.person_id
            AND ((value_coded = #{concept_id} AND concept_id = #{who_stages_criteria}) OR (concept_id = #{concept_id}) AND value_coded = #{yes_concept_id} )
            AND voided = 0 AND obs_datetime < DATE(date_enrolled) + INTERVAL 1 DAY
          WHERE date_enrolled >= '#{start_date}' AND date_enrolled <= '#{end_date}'
          GROUP BY patient_id
        SQL
      end

      def current_episode_of_tb(start_date, end_date)
        # CURRENT EPISODE OF TB
        eptb_concept_id = concept('EXTRAPULMONARY TUBERCULOSIS (EPTB)').concept_id
        yes_concept_id = concept('Yes').concept_id
        pulmonary_tb_concept_id = concept('PULMONARY TUBERCULOSIS').concept_id
        current_ptb_concept_id = concept('PULMONARY TUBERCULOSIS (CURRENT)').concept_id

        who_stages_criteria = concept('Who stages criteria present').concept_id

        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT *
          FROM temp_earliest_start_date t
          INNER JOIN obs ON t.patient_id = obs.person_id
          AND ( (value_coded IN (#{eptb_concept_id}, #{pulmonary_tb_concept_id}, #{current_ptb_concept_id}) AND concept_id = #{who_stages_criteria} )
            OR (concept_id IN (#{eptb_concept_id}, #{pulmonary_tb_concept_id}, #{current_ptb_concept_id}) AND value_coded = #{yes_concept_id}))
          AND voided = 0 AND obs_datetime < DATE(date_enrolled) + INTERVAL 1 DAY
          WHERE date_enrolled >= '#{start_date}' AND date_enrolled <= '#{end_date}'
          GROUP BY patient_id
        SQL
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
            AND voided = 0 AND obs_datetime < DATE(date_enrolled) + INTERVAL 1 DAY GROUP BY patient_id"
        )
      end

      def no_tb(total_registered, tb_within_the_last_two_years, current_episode_of_tb)
        total_registered_patients = []
        tb_within_2yrs_patients = []
        current_tb_episode_patients = []

        (total_registered || []).each do |patient|
          total_registered_patients << patient['patient_id'].to_i
        end

        (tb_within_the_last_two_years || []).each do |patient|
          tb_within_2yrs_patients << patient['patient_id'].to_i
        end

        (current_episode_of_tb || []).each do |patient|
          current_tb_episode_patients << patient['patient_id'].to_i
        end

        total_registered_patients - (tb_within_2yrs_patients + current_tb_episode_patients)
      end

      def cum_no_tb(cum_total_registered, cum_tb_within_the_last_two_years, cum_current_episode_of_tb)
        total_registered_patients = []
        tb_within_2yrs_patients = []
        current_tb_episode_patients = []

        (cum_total_registered || []).each do |patient|
          total_registered_patients << patient['patient_id'].to_i
        end

        (cum_tb_within_the_last_two_years || []).each do |patient|
          tb_within_2yrs_patients << patient['patient_id'].to_i
        end

        (cum_current_episode_of_tb || []).each do |patient|
          current_tb_episode_patients << patient['patient_id'].to_i
        end

        total_registered_patients - (tb_within_2yrs_patients + current_tb_episode_patients)
      end

      def children_12_59_months(start_date, end_date)
        concept = ConceptName.where(name: 'HIV Infected').select(:concept_id)

        find_patients_by_reason_for_starting(start_date, end_date, concept)
      end

      def unknown_other_reason_outside_guidelines(start_date, end_date)
        # All WHO stage 1 and 2 patients that were enrolled before '2016-04-01'
        # should be included in this group.
        unknown_concepts = ConceptName.where(name: %w[Unknown None])
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
                                            'CD4 count less than 350',
                                            'CD4 count less than 250',
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
        pregnant_women_ids = []
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

      def load_temp_pregnant_obs(start_date, end_date)
        ActiveRecord::Base.connection.execute <<~SQL
          INSERT INTO temp_pregnant_obs
          SELECT o.person_id,o.value_coded, MIN(DATE(o.obs_datetime)) obs_datetime
          FROM obs o
          WHERE o.concept_id IN (6131,1755,7972,7563)
            AND o.value_coded IN (1065,1755)
            AND o.voided = 0
            AND o.obs_datetime >= '#{start_date}' AND o.obs_datetime < '#{end_date}' + INTERVAL 1 DAY
          GROUP BY o.person_id
        SQL
      end

      def pregnant_females_all_ages(start_date, end_date)
        # (patient_id_plus_date_enrolled || []).each do |patient_id, date_enrolled|
        registered = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT tesd.*, ft.value_coded
          FROM temp_earliest_start_date tesd
          INNER JOIN temp_pregnant_obs ft ON ft.person_id = tesd.patient_id AND ft.obs_datetime = tesd.earliest_start_date
            AND tesd.gender = 'F'
          WHERE tesd.gender = 'F' and tesd.date_enrolled >= '#{start_date}' AND tesd.date_enrolled <= '#{end_date}'
          GROUP BY tesd.patient_id
        SQL

        pregnant_at_initiation = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_id
          FROM temp_earliest_start_date
          WHERE date_enrolled >= '#{start_date}' AND date_enrolled <= '#{end_date}'
            AND (gender = 'F' OR gender = 'Female') AND reason_for_starting_art IN (6131, 1755, 7972)
        SQL

        pregnant_at_initiation_ids = []
        (pregnant_at_initiation || []).each do |patient|
          pregnant_at_initiation_ids << patient['patient_id'].to_i
        end

        pregnant_at_initiation_ids = [0] if pregnant_at_initiation_ids.blank?

        # Inline replacement for re_initiated_check() stored function.
        # The function runs patient_date_enrolled() (a per-row sub-query) plus 2-3 obs lookups
        # for every patient. Replaced with a single set-based JOIN that mirrors the same logic:
        # Mirror dev branch exactly: call re_initiated_check() stored function per patient.
        # Our previous Ruby-based replacement using JOIN on encounter_type=9 was close but
        # missed the patient_date_enrolled(e.patient_id) = set_date_enrolled guard in the
        # stored function, which pins each registration encounter to the correct enrollment
        # period (avoiding false positives from old registrations). The stored function is
        # DETERMINISTIC and is only invoked on the small subset of pregnant-at-initiation
        # women with date_enrolled != earliest_start_date, so performance is acceptable.
        transfer_ins_women = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT patient_id, re_initiated_check(patient_id, date_enrolled) re_initiated
          FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND DATE(date_enrolled) != DATE(earliest_start_date)
            AND (gender = 'F' OR gender = 'Female')
            AND patient_id IN (#{pregnant_at_initiation_ids.join(',')})
          GROUP BY patient_id
          HAVING re_initiated != 'Re-initiated'
        SQL

        transfer_ins_preg_women = []
        all_pregnant_females = []
        (transfer_ins_women || []).each do |patient|
          transfer_ins_preg_women << patient['patient_id'].to_i if patient['patient_id'].to_i != 0
        end

        (registered || []).each do |patient|
          all_pregnant_females << patient['patient_id'].to_i if patient['patient_id'].to_i != 0
        end

        (all_pregnant_females + transfer_ins_preg_women).uniq
      end

      def initial_females_all_ages(start_date, end_date, data)
        clients = []
        women = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT * FROM temp_earliest_start_date e
          WHERE patient_id IN(#{data.length.positive? ? data.join(',') : 0})
          AND date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
          AND DATE(date_enrolled) = DATE(earliest_start_date)
        SQL

        (women || []).each do |w|
          clients << w
        end

        clients
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

        re_initiated_ids = re_initiated_on_art.nil? || re_initiated_on_art.empty? ? [0] : re_initiated_on_art.rows.collect(&:first)

        # Transfer-ins = enrolled in period, not first-time, not re-initiated on ART.
        # temp_re_initiated_patients was precomputed by precompute_min_ever_reg_obs, so we
        # just exclude those patient_ids directly — no need to repeat the 5-table obs join.
        ActiveRecord::Base.connection.select_all <<~SQL
          SELECT tesd.patient_id
          FROM temp_earliest_start_date tesd
          WHERE tesd.date_enrolled BETWEEN #{start_date} AND #{end_date}
            AND tesd.date_enrolled != tesd.earliest_start_date
            AND tesd.patient_id NOT IN (#{re_initiated_ids.join(',')})
          GROUP BY tesd.patient_id
        SQL
      end

      def precompute_min_ever_reg_obs
        conn = ActiveRecord::Base.connection
        conn.execute('DROP TABLE IF EXISTS temp_min_ever_reg_obs')
        conn.execute <<~SQL
          CREATE TABLE temp_min_ever_reg_obs (
            person_id    INT NOT NULL PRIMARY KEY,
            obs_datetime DATETIME NOT NULL
          ) ENGINE=MEMORY
        SQL
        conn.execute <<~SQL
          INSERT INTO temp_min_ever_reg_obs (person_id, obs_datetime)
          SELECT person_id, MIN(obs_datetime)
          FROM obs
          WHERE concept_id = 7937 AND voided = 0 AND value_coded = 1065
          GROUP BY person_id
        SQL

        # Precompute ALL re-initiated patients (no date filter) — stores patient_id +
        # date_enrolled from temp_earliest_start_date. Each of the 3 re_initiated_on_art
        # calls then becomes a fast range scan on this small table instead of re-running
        # the expensive 5-table join (25K patients × 10 encounters × obs scans) 3 times.
        date_art_last_taken_concept = conn.select_value(
          "SELECT concept_id FROM concept_name WHERE name = 'DATE ART LAST TAKEN' LIMIT 1"
        )

        conn.execute('DROP TABLE IF EXISTS temp_re_initiated_patients')
        conn.execute <<~SQL
          CREATE TABLE temp_re_initiated_patients (
            patient_id   INT NOT NULL PRIMARY KEY,
            date_enrolled DATE NOT NULL
          ) ENGINE=MEMORY
        SQL
        conn.execute <<~SQL
          INSERT INTO temp_re_initiated_patients (patient_id, date_enrolled)
          SELECT tesd.patient_id, tesd.date_enrolled
          FROM temp_earliest_start_date tesd
          INNER JOIN encounter enc
            ON enc.patient_id = tesd.patient_id
            AND enc.encounter_type = 9
            AND enc.voided = 0
          INNER JOIN obs ero
            ON ero.encounter_id = enc.encounter_id
            AND ero.concept_id = 7937
            AND ero.voided = 0
            AND ero.value_coded = 1065
          INNER JOIN temp_min_ever_reg_obs minero
            ON minero.person_id = ero.person_id
            AND minero.obs_datetime = ero.obs_datetime
          INNER JOIN obs lta
            ON lta.encounter_id = enc.encounter_id
            AND lta.voided = 0
            AND lta.concept_id = #{date_art_last_taken_concept.to_i}
          WHERE tesd.date_enrolled != tesd.earliest_start_date
            AND TIMESTAMPDIFF(DAY, lta.value_datetime, lta.obs_datetime) > 14
          GROUP BY tesd.patient_id, tesd.date_enrolled
        SQL
      end

      def re_initiated_on_art(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          <<~SQL
            SELECT patient_id
            FROM temp_re_initiated_patients
            WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
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
          date_enrolled >= start_date && date_enrolled <= end_date ? clients << e : next
        end

        clients
      end

      def get_cum_start_date
        cum_start_date = ActiveRecord::Base.connection.select_value(
          'SELECT MIN(date_enrolled) FROM temp_earliest_start_date'
        )

        begin
          cum_start_date.to_date
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

      def load_tmp_patient_table(_cohort_struct)
        create_tmp_patient_table
        #         arv_orders.each_with_object({}) do |order, patient_tab|
        #           next if patient_tab.include?(order.patient_id)
        #
        #           person = Person.find(order.patient_id)
        #           next unless person.birthdate # && patient_in_program?(person.patient)
        #
        #           add_patient_record(person, order, cohort_struct)
        #
        #           patient_tab[order.patient_id] = person
        #         end
      end

      def create_tmp_patient_table_2(_end_date)
        ##########################################################
        ActiveRecord::Base.connection.execute <<~SQL
          DROP FUNCTION IF EXISTS patient_date_enrolled;
        SQL

        Drug.arv_drugs.map(&:concept_id)

        ActiveRecord::Base.connection.execute <<~SQL
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
        SQL
        ##########################################################

        ActiveRecord::Base.connection.execute <<~SQL
          DROP TABLE IF EXISTS `temp_earliest_start_date`;
        SQL

        ActiveRecord::Base.connection.execute <<~SQL
          CREATE TABLE temp_earliest_start_date
            select
                `p`.`patient_id` AS `patient_id`,
                `pe`.`gender` AS `gender`,
                `pe`.`birthdate`,
                date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
                cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
                -- Pre-computed equivalent of date_antiretrovirals_started(patient_id, date_enrolled).
                -- Avoids calling the function per-row at query time (e.g. in cohort drill-down).
                date_antiretrovirals_started(`p`.`patient_id`, cast(patient_date_enrolled(`p`.`patient_id`) as date)) AS `earliest_start_date_by_enrollment`,
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
        SQL
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
        PatientState.find_by(program: program('HIV Program'), patient:)
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

        pprogram = PatientProgram.find_by(program: program('HIV Program'), patient:)
        return false unless pprogram

        PatientState.where(patient_program: pprogram, state: 7).exists?
      end
    end
  end
end
