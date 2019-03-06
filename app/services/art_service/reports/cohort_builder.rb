# frozen_string_literal: true

module ARTService
  module Reports
    class CohortBuilder
      QUARTER_LENGTH = 3.months

      include ModelUtils

      def build(cohort_struct, start_date, end_date)
        load_tmp_patient_table(cohort_struct)
        # create_tmp_patient_table_2(end_date)

        time_started = Time.now.strftime('%Y-%m-%d %H:%M:%S')

        # create_temp_earliest_start_date_table(end_date)
        quarter_start_date = end_date.to_date - QUARTER_LENGTH

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

        # Patients re-initiated on ART
        cohort_struct.re_initiated_on_art = re_initiated_on_art(start_date, end_date)
        cohort_struct.cum_re_initiated_on_art = re_initiated_on_art(cum_start_date, end_date)
        cohort_struct.quarterly_re_initiated_on_art = re_initiated_on_art(quarter_start_date, end_date)

        # Patients transferred in on ART
        cohort_struct.transfer_in = transfer_in(start_date, end_date)
        cohort_struct.cum_transfer_in = transfer_in(cum_start_date, end_date)
        cohort_struct.quarterly_transfer_in = transfer_in(quarter_start_date, end_date)

        # All males
        cohort_struct.all_males = males(start_date, end_date)
        cohort_struct.cum_all_males = males(cum_start_date, end_date)
        cohort_struct.quarterly_all_males = males(quarter_start_date, end_date)

        # Pregnant females (all ages)
        cohort_struct.pregnant_females_all_ages = pregnant_females_all_ages(start_date, end_date)
        cohort_struct.cum_pregnant_females_all_ages = pregnant_females_all_ages(cum_start_date, end_date)
        cohort_struct.quarterly_pregnant_females_all_ages = pregnant_females_all_ages(quarter_start_date, end_date)

        # Non-pregnant females (all ages)
        # Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
        # and earliest start date of the 'ON ARVs' state within the quarter and having gender of
        # related PERSON entry as F for female and no entries of 'IS PATIENT PREGNANT?' observation answered 'YES'
        # in related HIV CLINIC CONSULTATION encounters not within 28 days from earliest registration date
        cohort_struct.non_pregnant_females = non_pregnant_females(start_date, end_date, cohort_struct.pregnant_females_all_ages)
        cohort_struct.cum_non_pregnant_females = non_pregnant_females(cum_start_date, end_date, cohort_struct.cum_pregnant_females_all_ages)
        cohort_struct.quarterly_non_pregnant_females = non_pregnant_females(quarter_start_date, end_date, cohort_struct.cum_pregnant_females_all_ages)

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

        # The following block - we are calculating all reason for starting for Quarter and Cumulative
        initiated_reason_on_art_concept = concept('REASON FOR ART ELIGIBILITY')

        @reason_for_starting = ActiveRecord::Base.connection.select_all(
          "SELECT e.*, patient_reason_for_starting_art(e.patient_id) reason_for_starting_concept_id
           FROM temp_earliest_start_date e
           WHERE e.date_enrolled <= '#{end_date}'
           GROUP BY e.patient_id"
        ).collect do |data|
          {
            patient_id: data['patient_id'].to_i,
            gender: data['gender'],
            birthdate: data['birthdate'] ? data['birthdate'].to_date : nil,
            earliest_start_date: data['earliest_start_date'] ? data['earliest_start_date'].to_date : nil,
            date_enrolled: data['date_enrolled'] ? data['date_enrolled'].to_date : nil,
            reason_for_starting: data['reason'],
            age_at_initiation: data['age_at_initiation'] ? data['age_at_initiation'].to_i : nil,
            age_in_days: data['age_in_days'].to_i,
            reason_for_starting_concept_id: data['reason_for_starting_concept_id'] ? data['reason_for_starting_concept_id'].to_i : nil
          }
        end

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

        @regimen_categories = cal_regimem_category(cohort_struct.total_alive_and_on_art, end_date)

        cohort_struct.zero_a           = get_regimen_category('0A')
        cohort_struct.one_a            = get_regimen_category('1A')
        cohort_struct.zero_p           = get_regimen_category('0P')
        cohort_struct.one_p            = get_regimen_category('1P')
        cohort_struct.two_a            = get_regimen_category('2A')
        cohort_struct.two_p            = get_regimen_category('2P')
        cohort_struct.three_a          = get_regimen_category('3A')
        cohort_struct.three_p          = get_regimen_category('3P')
        cohort_struct.four_a           = get_regimen_category('4A')
        cohort_struct.four_p           = get_regimen_category('4P')
        cohort_struct.five_a           = get_regimen_category('5A')
        cohort_struct.six_a            = get_regimen_category('6A')
        cohort_struct.seven_a          = get_regimen_category('7A')
        cohort_struct.eight_a          = get_regimen_category('8A')
        cohort_struct.nine_a           = get_regimen_category('9A')
        cohort_struct.nine_p           = get_regimen_category('9P')
        cohort_struct.ten_a            = get_regimen_category('10A')
        cohort_struct.eleven_a        = get_regimen_category('11A')
        cohort_struct.eleven_p        = get_regimen_category('11P')
        cohort_struct.twelve_a         = get_regimen_category('12A')
        cohort_struct.thirteen_a       = get_regimen_category('13A')
        cohort_struct.fourteen_a       = get_regimen_category('14A')
        cohort_struct.fifteen_a       = get_regimen_category('15A')
        cohort_struct.unknown_regimen  = get_regimen_category('unknown_regimen')

        # Total patients with side effects:
        # Alive and On ART patients with DRUG INDUCED observations during their last HIV CLINIC CONSULTATION encounter up to the reporting period
        cohort_struct.total_patients_with_side_effects = total_patients_with_side_effects(cohort_struct, cohort_struct.total_alive_and_on_art, start_date, end_date)
        cohort_struct.total_patients_without_side_effects = total_patients_without_side_effects(cohort_struct.total_alive_and_on_art, cohort_struct.total_patients_with_side_effects)
        cohort_struct.unknown_side_effects = unknown_side_effects(cohort_struct.total_alive_and_on_art, start_date, end_date)

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
        cohort_struct.total_breastfeeding_women = total_breastfeeding_women(cohort_struct.total_alive_and_on_art, start_date, end_date)
        cohort_struct.total_other_patients = total_other_patients(cohort_struct.total_alive_and_on_art, cohort_struct.total_breastfeeding_women, cohort_struct.total_pregnant_women)

        # Patients with CPT dispensed at least once before end of quarter and on ARVs
        cohort_struct.total_patients_on_arvs_and_cpt = total_patients_on_arvs_and_cpt(cohort_struct.total_alive_and_on_art, start_date, end_date)

        # Patients with IPT dispensed at least once before end of quarter and on ARVS
        cohort_struct.total_patients_on_arvs_and_ipt = total_patients_on_arvs_and_ipt(cohort_struct.total_alive_and_on_art, start_date, end_date)

        # Patients on family planning methods at least once before end of quarter and on ARVs
        cohort_struct.total_patients_on_family_planning = total_patients_on_family_planning(cohort_struct.total_alive_and_on_art, quarter_start_date, end_date)

        # Patients whose BP was screened and are above 30 years least once before end of quarter and on ARVs
        cohort_struct.total_patients_with_screened_bp = total_patients_with_screened_bp(cohort_struct.total_alive_and_on_art, start_date, end_date)

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

        [(begin
            data.length
          rescue StandardError
            0
          end),
         (begin
           data1.length
          rescue StandardError
            0
         end),
         (begin
           data2.length
          rescue StandardError
            0
         end),
         0]
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

      def patient_on_pre_ART_but_have_arvs_dispensed(start_date, end_date)
        begin
          patients = ActiveRecord::Base.connection.select_all(
            "SELECT e.* FROM temp_earliest_start_date e
             INNER JOIN temp_patient_outcomes o ON e.patient_id = o.patient_id
             WHERE date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}'
             AND cum_outcome LIKE '%Pre-%'"
          )
        rescue StandardError
          raise 'Try running the revised cohort before this report'
        end

        data = {}

        (patients || []).each do |p|
          patient = Patient.find(p['patient_id'].to_i)
          reason_for_starting = PatientService.reason_for_art_eligibility(patient)
          # next unless reason_for_starting.blank?

          patient_outcome = ActiveRecord::Base.connection.select_one(
            "SELECT patient_outcome(#{patient.patient_id}, DATE('#{end_date.to_date}')) AS outcome"
          )

          patient_obj = PatientService.get_patient(patient.person)
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
            outcome: patient_outcome['outcome']
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

      def missing_arv_dispensions(_start_date, end_date)
        begin
          patients = ActiveRecord::Base.connection.select_all(
            "SELECT e.*, patient_reason_for_starting_art_text(e.patient_id) reason_for_starting
            FROM temp_earliest_start_date e
            WHERE (date_enrolled IS NULL OR LENGTH(date_enrolled) < 1)"
          )
        rescue StandardError
          raise 'Try running the revised cohort before this report'
        end

        data = {}

        (patients || []).each do |p|
          patient = Patient.find(p['patient_id'].to_i)

          patient_outcome = ActiveRecord::Base.connection.select_one(
            "SELECT patient_outcome(#{patient.patient_id}, DATE('#{end_date.to_date}')) AS outcome"
          )

          patient_obj = PatientService.get_patient(patient.person)
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
            reason_for_starting: p['reason_for_starting'],
            birthdate: patient_obj.birth_date,
            outcome: patient_outcome['outcome']
          }
        end

        data
      end

      private

      def total_patients_with_screened_bp(patients_list, _start_date, end_date)
        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        result = []

        systolic_blood_presssure_concept_id = concept('Systolic blood pressure').concept_id
        diastolic_pressure_concept_id = concept('Diastolic blood pressure').concept_id

        results = ActiveRecord::Base.connection.select_all(
          "SELECT o.person_id
          FROM obs o
          WHERE o.voided = 0 AND (o.concept_id in (#{systolic_blood_presssure_concept_id}, #{diastolic_pressure_concept_id}) AND o.value_text IS NOT NULL)
          AND o.person_id IN (#{patient_ids.join(',')})
          AND o.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
          AND DATE(o.obs_datetime) = (SELECT max(date(obs.obs_datetime)) FROM obs obs
                                      WHERE obs.voided = 0
                                      AND (obs.concept_id IN (#{systolic_blood_presssure_concept_id}, #{diastolic_pressure_concept_id}) AND obs.value_text IS NOT NULL)
                                      AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
                                      AND obs.person_id = o.person_id)
          GROUP BY o.person_id;"
        )

        total_percent = ((results.count.to_f / patient_ids.count.to_f) * 100).to_i
        total_percent
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

      def total_breastfeeding_women(patients_list, start_date, end_date)
        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        result = []

        total_pregnant_females = []
        (total_pregnant_women(patients_list, start_date, end_date) || []).each do |person|
          total_pregnant_females << person['person_id'].to_i
        end

        total_pregnant_females = [0] if total_pregnant_females.blank?

        hiv_clinic_consultation_encounter_type_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').encounter_type_id
        breastfeeding_concept_id = concept('Breast feeding?').concept_id

        results = ActiveRecord::Base.connection.select_all(
          "SELECT person_id  FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id AND enc.voided = 0
          WHERE obs.person_id IN (#{patient_ids.join(',')})
          AND obs.person_id NOT IN (#{total_pregnant_females.join(',')})
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.concept_id = #{breastfeeding_concept_id} AND obs.value_coded = 1065
          AND obs.voided = 0 AND enc.encounter_type = #{hiv_clinic_consultation_encounter_type_id}
          AND DATE(obs.obs_datetime) = (SELECT MAX(DATE(o.obs_datetime)) FROM obs o
                        WHERE o.concept_id = #{breastfeeding_concept_id} AND voided = 0
                        AND o.person_id = obs.person_id AND o.obs_datetime <='#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY obs.person_id"
        )

        results
      end

      def total_pregnant_women(patients_list, _start_date, end_date)
        patient_ids = []
        (patients_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        result = []

        hiv_clinic_consultation_encounter_type_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').encounter_type_id
        pregnant_concept_id = concept('Is patient pregnant?').concept_id

        results = ActiveRecord::Base.connection.select_all(
          "SELECT person_id FROM obs obs
            INNER JOIN encounter enc ON enc.encounter_id = obs.encounter_id AND enc.voided = 0
          WHERE obs.person_id IN (#{patient_ids.join(',')})
          AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.concept_id = #{pregnant_concept_id} AND obs.value_coded = '1065'
          AND obs.voided = 0 AND enc.encounter_type = #{hiv_clinic_consultation_encounter_type_id}
          AND DATE(obs.obs_datetime) = (SELECT MAX(DATE(o.obs_datetime)) FROM obs o
                        WHERE o.concept_id = #{pregnant_concept_id} AND voided = 0
                        AND o.person_id = obs.person_id AND o.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}')
          GROUP BY obs.person_id"
        )

        results
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

      ART_ADHERENCE_THRESHOLD = 95.0 # Those below are not adherent

      # Groups patients list into three groups based on the adherence rates
      #
      # Returns: A list of 3 lists as follows:
      #    [
      #       [adherent patients],
      #       [inadherent patients],
      #       [patients whose adherence rate is unknown]
      #    ]
      def latest_art_adherence(patients_alive_and_on_art, start_date, end_date)
        adherent = []
        not_adherent = []
        unknown_adherence = []

        patients_alive_and_on_art.each do |patient|
          adherence = patient_latest_art_adherence(patient['patient_id'], start_date, end_date)

          unless adherence
            unknown_adherence << patient
            next
          end

          adherence_rate = (adherence.value_numeric || adherence.value_text).to_f

          if adherence_rate >= ART_ADHERENCE_THRESHOLD
            adherent << patient
          else
            not_adherent << patient
          end
        end

        [adherent, not_adherent, unknown_adherence]
      end

      # Retrieve patient's latest adherence observation
      def patient_latest_art_adherence(patient_id, start_date, end_date)
        encounter = EncounterService.recent_encounter(
          encounter_type_name: 'ART ADHERENCE',
          patient_id: patient_id,
          date: end_date,
          start_date: start_date
        )
        return nil unless encounter

        encounter.observations.where(
          concept: concept('Drug order adherence')
        ).order(obs_datetime: :desc).first
      end

      def unknown_side_effects(data, _start_date, end_date)
        patient_ids = []
        (data || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        result = []

        drug_induced_concept_id = concept('Drug induced').concept_id
        malawi_art_side_effects_concept_id = concept('Malawi ART side effects').concept_id
        unknown_side_effects_concept_id = concept('Unknown').concept_id

        malawi_art_side_effects = ActiveRecord::Base.connection.select_all(
          "SELECT * FROM obs o
          WHERE o.voided = 0
            AND o.concept_id IN (#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id} )
            AND o.value_coded = #{unknown_side_effects_concept_id}
            AND (o.person_id IN (#{patient_ids.join(',')}))
            AND o.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            AND o.obs_datetime = (
              SELECT min(obs_datetime) FROM obs WHERE concept_id IN (#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id})
              AND voided = 0 AND person_id = o.person_id
              AND obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
            ) GROUP BY person_id"
        )

        (malawi_art_side_effects || []).each do |row|
          result << row
        end
        result
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

        patients_alive_and_on_art.each do |patient|
          tb_status = patient_tb_status(patient['patient_id'], start_date, end_date)

          tb_status_value = tb_status ? tb_status.value_coded.to_i : nil

          case tb_status_value
          when tb_suspected_concept.concept_id
            cohort_struct.tb_suspected << patient
          when tb_not_suspected_concept.concept_id
            cohort_struct.tb_not_suspected << patient
          when tb_confirmed_and_on_treatment.concept_id
            cohort_struct.tb_confirmed_on_tb_treatment << patient
          when tb_confirmed_but_not_on_treatment.concept_id
            cohort_struct.tb_confirmed_currently_not_yet_on_tb_treatment << patient
          else
            cohort_struct.unknown_tb_status << patient
          end
        end
      end

      def patient_tb_status(patient_id, start_date, end_date)
        tb_status_concept = concept('TB Status')

        encounter = EncounterService.recent_encounter(
          encounter_type_name: 'HIV CLINIC CONSULTATION',
          patient_id: patient_id,
          date: end_date,
          start_date: start_date
        )
        return false unless encounter

        Observation.where(
          'person_id = ? AND concept_id = ? AND DATE(obs_datetime) = DATE(?)',
          patient_id, tb_status_concept.concept_id, encounter.encounter_datetime
        ).first
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

      def total_patients_with_side_effects(_cohort_struct, patients_alive_and_on_art, start_date, end_date)
        patients_alive_and_on_art.select do |record|
          patient_has_art_side_effect?(record['patient_id'], start_date, end_date)
        end
      end

      def patient_has_art_side_effect?(patient_id, start_date, end_date)
        encounter = EncounterService.recent_encounter(
          encounter_type_name: 'HIV CLINIC CONSULTATION',
          patient_id: patient_id,
          date: end_date,
          start_date: start_date
        )
        return false unless encounter

        art_side_effects_concept = concept('Malawi ART Side Effects')
        yes_concept = concept('Yes')

        # Unfortunately side effects may be collected on the first day under
        # the same 'Malawi ART Side Effects concept. We don't want any
        # side effects captured on the first day.
        patient_start_date = patient_earliest_start_date(patient_id, end_date)

        records = ActiveRecord::Base.connection.select_all(
          "SELECT concept_id, value_coded FROM obs
           WHERE obs_group_id IN (
             SELECT obs_id FROM obs
             WHERE concept_id = #{art_side_effects_concept.concept_id}
                AND person_id = #{patient_id}
                AND DATE(obs_datetime) = DATE('#{encounter.encounter_datetime}')
                AND DATE(obs_datetime) != DATE('#{patient_start_date}')
           ) GROUP BY concept_id HAVING value_coded = '#{yes_concept.concept_id}'
           LIMIT 1"
        )

        records.length.positive?
      end

      def total_patients_without_side_effects(patients_alive_and_on_art, patients_with_side_effects)
        patient_ids = []; with_side_effects = []; result = []

        (patients_alive_and_on_art || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        # get all patients with side effects
        (patients_with_side_effects || []).each do |row|
          with_side_effects << row['patient_id'].to_i
        end

        # get all patients with unknown_side_effects
        result = patient_ids - with_side_effects
        result
      end

      def cal_regimem_category(patient_list, end_date)
        regimens = []

        patient_ids = []

        (patient_list || []).each do |row|
          patient_ids << row['patient_id'].to_i
        end

        return [] if patient_ids.blank?

        dispensing_encounter_id = EncounterType.find_by_name('DISPENSING').id
        regimen_category = concept('REGIMEN CATEGORY').concept_id
        regimem_given_concept = concept('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT').concept_id
        unknown_regimen_given = concept('UNKNOWN ANTIRETROVIRAL DRUG').concept_id

        data = ActiveRecord::Base.connection.select_all(
          "SELECT e.patient_id, patient_current_regimen(e.patient_id, DATE('#{end_date.to_date}')) regimen_category
          FROM temp_earliest_start_date e
          WHERE patient_id IN(#{patient_ids.join(',')})
          GROUP BY e.patient_id"
        )
        current_cohort_regimens = %w[
          0P 2P 4P 9P 11P 0A 2A 4A
          5A 6A 7A 8A 9A 10A 11A 12A
          13A 14A 15A
        ]

        (data || []).each do |regimen_attr|
          regimen = regimen_attr['regimen_category']

          if regimen.blank? || (regimen == 'Unknown') || !current_cohort_regimens.include?(regimen)
            regimen = 'unknown_regimen'
          end

          regimens << {
            patient_id: regimen_attr['patient_id'].to_i,
            regimen_category: regimen
          }
        end
        regimens
      end

      def get_regimen_category(arv_regimen_category)
        registered = []
        (@regimen_categories || []).each do |regimen_attr|
          if arv_regimen_category == regimen_attr[:regimen_category]
            registered << { patient_id: regimen_attr[:patient_id], regimen: regimen_attr[:regimen_category] }
          end
        end

        registered
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
          registered << patient
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

      def update_cum_outcome(end_date)
        ActiveRecord::Base.connection.execute(
          'DROP TABLE IF EXISTS `temp_patient_outcomes`'
        )

        ActiveRecord::Base.connection.execute(
          "CREATE TABLE temp_patient_outcomes ENGINE=MEMORY AS (
            SELECT e.patient_id, patient_outcome(e.patient_id, '#{end_date} 23:59:59') AS cum_outcome
            FROM temp_earliest_start_date e WHERE e.date_enrolled <= '#{end_date}'
          )"
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_outcomes
           ADD INDEX patient_id_index (patient_id)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_outcomes
           ADD INDEX cum_outcome_index (cum_outcome)'
        )

        ActiveRecord::Base.connection.execute(
          'ALTER TABLE temp_patient_outcomes
           ADD INDEX patient_id_cum_outcome_index (patient_id, cum_outcome)'
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
        reason_concept_id = concept('HIV Infected').concept_id

        registered = []

        (@reason_for_starting || []).each do |r|
          next unless reason_concept_id == r[:reason_for_starting_concept_id]
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def unknown_other_reason_outside_guidelines(start_date, end_date)
        # All WHO stage 1 and 2 patients that were enrolled before '2016-04-01'
        # should be included in this group.
        reason_concept_ids = []
        reason_concept_ids << concept('Unknown').concept_id
        reason_concept_ids << concept('None').concept_id

        registered = []

        (@reason_for_starting || []).each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id]) && !r[:reason_for_starting_concept_id].blank?
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        revised_art_guidelines_date = '2016-04-01'.to_date
        who_stage_1_and_2_concept_ids = []
        who_stage_1_and_2_concept_ids << concept('LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1').concept_id
        who_stage_1_and_2_concept_ids << concept('LYMPHOCYTES').concept_id
        who_stage_1_and_2_concept_ids << concept('LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2').concept_id
        who_stage_1_and_2_concept_ids << concept('WHO stage I adult').concept_id
        who_stage_1_and_2_concept_ids << concept('WHO stage I peds').concept_id
        who_stage_1_and_2_concept_ids << concept('WHO stage 1').concept_id
        who_stage_1_and_2_concept_ids << concept('WHO stage II adult').concept_id
        who_stage_1_and_2_concept_ids << concept('WHO stage II peds').concept_id

        if start_date.to_date < revised_art_guidelines_date.to_date
          end_date = revised_art_guidelines_date

          (@reason_for_starting || []).each do |r|
            next unless who_stage_1_and_2_concept_ids.include?(r[:reason_for_starting_concept_id])
            next unless r[:date_enrolled] < end_date

            registered << r
          end
        end
        registered
      end

      def who_stage_four(start_date, end_date)
        reason_concept_ids = []
        reason_concept_ids << concept('WHO stage IV adult').concept_id
        reason_concept_ids << concept('WHO stage IV peds').concept_id
        reason_concept_ids << concept('WHO STAGE 4').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id])
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def who_stage_three(start_date, end_date)
        reason_concept_ids = []
        reason_concept_ids << concept('WHO stage III adult').concept_id
        reason_concept_ids << concept('WHO stage III peds').concept_id
        reason_concept_ids << concept('WHO STAGE 3').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id].to_i)
          next unless r[:date_enrolled] >= start_date.to_date && r[:date_enrolled] <= end_date.to_date

          registered << r
        end

        registered
      end

      def pregnant_women(start_date, end_date)
        reason_concept_ids = []
        reason_concept_ids << concept('PATIENT PREGNANT').concept_id
        reason_concept_ids << concept('Is patient pregnant at initiation?').concept_id
        reason_concept_ids << concept('Patient pregnant state').concept_id
        reason_concept_ids << concept('Is patient pregnant?').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id])
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def breastfeeding_mothers(start_date, end_date)
        reason_concept_id = concept('BREASTFEEDING').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_id == r[:reason_for_starting_concept_id]
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def asymptomatic(start_date, end_date)
        # for WHO stage 1 and 2 to be included in asymptomatic, the patients are supposed to
        # be enrolled on HIV program after 2016-04-01

        revised_art_guidelines_date = '2016-04-01'.to_date
        reason_concept_ids = []
        asymptomatic_concept_ids = []
        asymptomatic_concept_ids << concept('ASYMPTOMATIC').concept_id
        reason_concept_ids << concept('WHO stage I adult').concept_id
        reason_concept_ids << concept('WHO stage I peds').concept_id
        reason_concept_ids << concept('WHO stage 1').concept_id
        reason_concept_ids << concept('WHO stage II adult').concept_id
        reason_concept_ids << concept('WHO stage II peds').concept_id
        reason_concept_ids << concept('LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1').concept_id
        reason_concept_ids << concept('LYMPHOCYTES').concept_id
        reason_concept_ids << concept('LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2').concept_id

        registered = []
        @reason_for_starting.each do |r|
          next unless asymptomatic_concept_ids.include?(r[:reason_for_starting_concept_id])

          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        start_date = if start_date.to_date >= revised_art_guidelines_date.to_date
                       start_date
                     else
                       revised_art_guidelines_date
                     end

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id])

          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def who_stage_two(start_date, end_date)
        reason_concept_ids = []
        reason_concept_ids << concept('CD4 COUNT LESS THAN OR EQUAL TO 750').concept_id
        reason_concept_ids << concept('CD4 count less than or equal to 500').concept_id
        reason_concept_ids << concept('CD4 COUNT LESS THAN OR EQUAL TO 350').concept_id
        reason_concept_ids << concept('CD4 COUNT LESS THAN OR EQUAL TO 250').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id])
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def confirmed_hiv_infection_in_infants_pcr(start_date, end_date)
        reason_concept_id = concept('HIV PCR').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless r[:reason_for_starting_concept_id] == reason_concept_id
          next unless r[:date_enrolled].to_date >= start_date.to_date && r[:date_enrolled].to_date <= end_date.to_date

          registered << r
        end

        registered
      end

      def presumed_severe_hiv_disease_in_infants(start_date, end_date)
        reason_concept_ids = []
        reason_concept_ids << concept('PRESUMED SEVERE HIV').concept_id
        reason_concept_ids << concept('PRESUMED SEVERE HIV CRITERIA IN INFANTS').concept_id

        registered = []

        @reason_for_starting.each do |r|
          next unless reason_concept_ids.include?(r[:reason_for_starting_concept_id])
          next unless (r[:date_enrolled] >= start_date.to_date) && (r[:date_enrolled] <= end_date.to_date)

          registered << r
        end

        registered
      end

      def unknown_age(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND (age_at_initiation IS NULL OR age_at_initiation < 0 OR birthdate IS NULL)
          GROUP BY patient_id"
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
          "SELECT * FROM temp_earliest_start_date t
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND (gender = 'F' OR gender = 'Female')
          AND t.patient_id NOT IN(#{pregnant_women_ids.join(',')}) GROUP BY patient_id"
        )
      end

      def pregnant_females_all_ages(start_date, end_date)
        registered = []; patient_id_plus_date_enrolled = []

        yes_concept_id = concept('Yes').concept_id
        preg_concept_id = concept('IS PATIENT PREGNANT?').concept_id
        patient_preg_concept_id = concept('PATIENT PREGNANT').concept_id
        preg_at_initiation_concept_id = concept('PREGNANT AT INITIATION?').concept_id

        # (patient_id_plus_date_enrolled || []).each do |patient_id, date_enrolled|
        registered = ActiveRecord::Base.connection.select_all(
          "SELECT t.* , o.value_coded FROM temp_earliest_start_date t
            INNER JOIN obs o ON o.person_id = t.patient_id AND o.voided = 0
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND (gender = 'F' OR gender = 'Female')
            AND o.concept_id IN (#{preg_concept_id} , #{patient_preg_concept_id}, #{preg_at_initiation_concept_id})
            AND DATE(o.obs_datetime) = DATE(t.earliest_start_date)
          GROUP BY patient_id
          HAVING value_coded = #{yes_concept_id}"
        )

        pregnant_at_initiation = ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, patient_reason_for_starting_art(patient_id) reason_concept_id
          FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND (gender = 'F' OR gender = 'Female')
          GROUP BY patient_id
          HAVING reason_concept_id IN (1755, 7972, 6131)"
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

      def males(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date t
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND (gender = 'Male' OR gender = 'M') GROUP BY patient_id"
        )
      end

      def transfer_in(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, re_initiated_check(patient_id, date_enrolled) re_initiated FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
          AND DATE(date_enrolled) != DATE(earliest_start_date)
          GROUP BY patient_id
          HAVING re_initiated != 'Re-initiated'"
        )
      end

      def re_initiated_on_art(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT patient_id, re_initiated_check(patient_id, date_enrolled) re_initiated FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND DATE(date_enrolled) != DATE(earliest_start_date)
          GROUP BY patient_id
          HAVING re_initiated = 'Re-initiated'"
        )
      end

      def initiated_on_art_first_time(start_date, end_date)
        ActiveRecord::Base.connection.select_all(
          "SELECT * FROM temp_earliest_start_date
          WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
            AND DATE(date_enrolled) = DATE(earliest_start_date)
          GROUP BY patient_id"
        )
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

        arv_orders.each_with_object({}) do |order, patient_tab|
          next if patient_tab.include?(order.patient_id)

          person = Person.find(order.patient_id)
          next unless person.birthdate # && patient_in_program?(person.patient)

          add_patient_record(person, order, cohort_struct)

          patient_tab[order.patient_id] = person
        end
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

      def create_tmp_patient_table
        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_earliest_start_date')
        ActiveRecord::Base.connection.execute(
          'CREATE TABLE IF NOT EXISTS temp_earliest_start_date (
             patient_id INTEGER PRIMARY KEY,
             date_enrolled DATE NOT NULL,
             earliest_start_date DATETIME NOT NULL,
             birthdate DATE NOT NULL,
             birthdate_estimated BOOLEAN,
             death_date DATE,
             gender VARCHAR(32),
             age_at_initiation INT NOT NULL,
             age_in_days INT NOT NULL
          ) ENGINE=MEMORY;'
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
          'CREATE INDEX earliest_start_date__date_enrolled_index ON temp_earliest_start_date (earliest_start_date, date_enrolled)'
        )
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
        # latest_outcome = patient_latest_outcome(order.patient_id, @cut_off_date)
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

      # Returns latest outcome for given patient relative to report date.
      def patient_latest_outcome(patient_id, report_date = Time.now)
        result = ActiveRecord::Base.connection.select_one(
          "SELECT patient_outcome(#{patient_id}, '#{report_date}') AS outcome"
        )
        result['outcome']
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
