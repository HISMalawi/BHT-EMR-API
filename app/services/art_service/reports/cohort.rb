# frozen_string_literal: true

require 'set'

module ARTService
  module Reports
    class Cohort
      include CohortTools

      def initialize(type:, date: Date.today)
        @cut_off_date = date
      end

      def start_build_report
        load_tmp_patient_table
        build_report
      end

      def method_missing(name, *args, &block)
        name_prefix, name_suffix = split_missing_method_name(name)

        unless COHORT_REPORT_FIELD_NAME_MAP.include?(name_prefix)
          return super(name, *args, &block)
        end

        field = report_value(name_suffix)
        field.contents = args[0] if match[2]
        field.contents
      end

      def respond_to_missing?(name)
        field_name, = split_missing_method_name(name)
        COHORT_REPORT_FIELD_NAME_MAP.include?(field_name)
      end

      private

      COHORT_REPORT_FIELD_NAME_MAP = {
        total_other_patients: 'All others (not circled)',
        patients_with_7_plus_doses_missed_at_their_last_visit: 'Adherence: 4+ Doses',
        unknown_age: 'Unknown age',
        cum_pregnant_females_all_ages: 'Cumulative female pregnant patients (all ages)',
        died_within_the_2nd_month_of_art_initiation: 'Died within the 2nd month of art initiation',
        no_tb: 'Never TB or TB over 2 years ago',
        six_a: 'Regimen: 6 A',
        elleven_p: 'Regimen: 11 P',
        cum_children_24_months_14_years_at_art_initiation: 'Cumulative Children 24 m - 14 yrs at ART initiation',
        cum_no_tb: 'Cumulative Never TB or TB over 2 years ago',
        cum_current_episode_of_tb: 'Cumulative Current episode of TB',
        who_stage_two: ' CD4 below threshold',
        cum_non_pregnant_females: 'Cumulative FNP:Non-pregnant Females (all ages)',
        asymptomatic: 'Asy:Asymptomatic / mild',
        cum_initiated_on_art_first_time: 'Cumulative Patients initiated on ART first time',
        pregnant_women: 'Pregnant women',
        defaulted: 'Defaulted (more than 2 months overdue after expected to have run out of ARVs',
        four_p: ' Regimen: 4 P',
        tb_within_the_last_two_years: 'TB within the last 2 years',
        total_patients_without_side_effects: 'Side Effects:as of the last visit before end of quarter',
        cum_pregnant_women: 'Cumulative Pregnant Women',
        cum_re_initiated_on_art: 'Cumulative Patients re-initiated on ART',
        cum_all_males: 'Cumulative Males (all ages)',
        cum_children_12_23_months: 'Cumulative Children 12-59 months',
        current_episode_of_tb: 'Current episode of TB',
        re_initiated_on_art: 'Patients re-initiated on ART',
        cum_unknown_other_reason_outside_guidelines: 'Cumulative Unknown / reason outside guidelines',
        cum_kaposis_sarcoma: "Cumulative Kaposi's Sarcoma",
        three_p: 'Regimen: 3 A',
        cum_children_below_24_months_at_art_initiation: 'Cumulative Children below 24 m at ART initiation',
        total_patients_with_side_effects: 'Any side effects',
        adults_at_art_initiation: 'Adults 15 years or older at ART initiation',
        total_patients_on_family_planning: 'PIFP:Apprx. % of women who received Depo at ART in the last quarter',
        zero_a: 'Regimen: 0 A',
        total_pregnant_women: 'Pregnant/BreastFeeding as of the last visit before end of quarter',
        nine_a: 'Regimen: 9 A',
        two_p: 'Regimen: 2 P',
        cum_adults_at_art_initiation: 'Cumulative Adults 15 years or older at ART initiation',
        cum_breastfeeding_mothers: 'Cumulative Breastfeeding mothers ',
        died_total: 'Died Total',
        tb_confirmed_currently_not_yet_on_tb_treatment: 'TB conf.',
        transfered_out: 'Transferred Out',
        cum_who_stage_four: 'Cumulative  WHO stage 4',
        cum_presumed_severe_hiv_disease_in_infants: 'Cumulative Pres. Sev. HIV disease age < 12 m',
        twelve_a: 'Regimen: 12 A',
        children_12_23_months: 'Children 12-59 mths',
        tb_not_suspected: 'Current TB status any form of TB',
        one_p: 'Regimen: 1 P',
        breastfeeding_mothers: 'Breastfeeding mothers',
        tb_confirmed_on_tb_treatment: 'TB conf.',
        patients_with_0_6_doses_missed_at_their_last_visit: 'Adnerence: as of the last visit before end of quarter',
        cum_transfer_in: 'Cumulative Patients transferred in on ART ',
        total_patients_on_arvs_and_ipt: 'Apprx. % of patients retained in <b>ART</b> who are currently on IPT',
        total_breastfeeding_women: 'Total Breastfeeding Women',
        total_alive_and_on_art: ' Total alive and on ART',
        kaposis_sarcoma: "Kaposi's Sarcoma",
        five_a: 'Regimen: 5 A',
        cum_tb_within_the_last_two_years: 'Cumulative TB within the last 2 years',
        unknown_regimen: "Specify above regimens counted as 'Other' Other (paed. / adult)",
        total_patients_with_screened_bp: 'BP screen:Apprx. % of adult ART patients with BP recorded at least once this year',
        elleven_a: 'Regimen: 11 A',
        died_within_the_3rd_month_of_art_initiation: 'M3: Died within the 3rd month after ART initiation',
        cum_unknown_age: 'Cumulative Unknown Age',
        cum_total_registered: 'Cumulative Total Registered',
        eight_a: 'Regimen: 8 A',
        transfer_in: 'Patients transferred in on ART',
        confirmed_hiv_infection_in_infants_pcr: 'PCR:Infants < 12 mths PCR+',
        four_a: 'Regimen: 4 A',
        who_stage_four: 'WHO stage 4',
        non_pregnant_females: 'FNP: Non-pregnant Females (all ages)',
        cum_who_stage_two: 'Cumulative CD4 below threshold',
        cum_confirmed_hiv_infection_in_infants_pcr: 'Cumulative PCR: Infants < 12 mths PCR+',
        unknown_tb_status: 'Unknown (not circled)',
        three_a: 'Regimen 3 A',
        zero_p: 'Regimen: 0 P',
        total_patients_on_arvs_and_cpt: 'Apprx. % of patients retained in <b>ART</b> who are currently on CPT',
        tb_suspected: 'TB Suspected',
        unknown_side_effects: 'Unkown (not circled)',
        seven_a: 'Regimen: 7 A',
        total_registered: 'Total Registered',
        nine_p: 'Regimen: 9 A',
        died_within_the_1st_month_of_art_initiation: 'Died within the 1st month after ART initiation',
        pregnant_females_all_ages: 'FP: Pregnant Females (all ages)',
        patients_with_unknown_adhrence: 'Unknown (not circled)',
        two_a: 'Regimen: 2 A',
        died_after_the_3rd_month_of_art_initiation: 'Died within the 3rd month after ART initiation',
        who_stage_three: 'WHO stage 3',
        cum_asymptomatic: 'Cumulative Asymptomatic / mild',
        unknown_other_reason_outside_guidelines: 'Unknown / reason outside guidelines',
        ten_a: 'Regimen: 10 A',
        initiated_on_art_first_time: 'Patients initiated on ART first time',
        cum_who_stage_three: 'Cumulative WHO stage 3',
        presumed_severe_hiv_disease_in_infants: 'Pres. Sev. HIV disease age < 12 m',
        children_24_months_14_years_at_art_initiation: 'Children 24 m - 14 yrs at ART initiation',
        one_a: 'Regimen: 1 A',
        all_males: 'Males (all ages)',
        stopped_art: 'Stopped taking ARVs (clinician or patient own decision, last known alive)',
        children_below_24_months_at_art_initiation: 'Children below 24 m at ART initiation'
      }.freeze

      def load_tmp_patient_table
        create_tmp_patient_table

        arv_orders.each_with_object(Set.new) do |order, patient_tab|
          next if patient_tab.include?(order.patient_id)

          person = Person.find(order.patient_id)
          next unless person.birthdate

          add_patient_record(person, order)

          patient_tab << order.patient_id
        end
      end

      # Returns a ReportValue object for the given name
      def report_value(name)
        @report_values[name] ||= ReportValue.new(
          name: name, description: COHORT_REPORT_FIELD_NAME_MAP[name]
        )
      end

      def split_missing_method_name(name)
        match = name.match(/([A-Z0-9])+(=)?$/)
        [match[1], match[2]]
      end

      def create_tmp_patient_table
        ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS temp_cohort_report')
        ActiveRecord::Base.connection.execute(
          'CREATE TABLE IF NOT EXISTS temp_cohort_report (
             patient_id INTEGER PRIMARY KEY,
             art_start_date DATETIME NOT NULL,
             art_earliest_start_date DATETIME NOT NULL,
             birthdate DATE NOT NULL,
             birthdate_estimated BOOLEAN,
             age_when_starting INT NOT NULL,
             latest_outcome VARCHAR(255)
          ) ENGINE=MEMORY;'
        )
      end

      def arv_orders
        Order.joins(:drug_order).where(
          'drug_order.drug_inventory_id in (?)', Drug.arv_drugs.collect(&:drug_id)
        ).order(:start_date)
      end

      def add_patient_record(person, order)
        art_earliest_start_date = patient_earliest_start_date(order.patient_id, order.start_date)
        age_when_starting = art_earliest_start_date - person.birthdate
        latest_outcome = patient_latest_outcome(order.patient_id, @cut_off_date)

        ActiveRecord::Base.connection.execute(
          "INSERT INTO temp_cohort_report (
              patient_id, art_start_date, art_earliest_start_date, birthdate,
              birthdate_estimated, age_when_starting, latest_outcome
           ) VALUES (
              #{order.patient_id}, '#{order.start_date.to_date}',
              '#{art_earliest_start_date.to_date}', '#{person.birthdate.to_date}',
              #{person.birthdate_estimated}, #{age_when_starting}, '#{latest_outcome}'
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
    end
  end
end
