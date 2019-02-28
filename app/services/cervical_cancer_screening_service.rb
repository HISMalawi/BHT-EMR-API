# frozen_string_literal: true

class CervicalCancerScreeningService
  def report(patient, session_date)
    screening_report = {
      via_referred: false,
      has_via_results: false,
      remaining_days: 0,
      terminal: false,
      lesion_size_too_big: false,
      cervical_cancer_first_visit_patient: true,
      no_cancer: false,
      patient_went_for_via: false,
      cryo_delayed: false
    }
    ##### patient went for via logic START ################

    ##### patient went for via logic END###################
    terminal_referral_outcomes = ['PRE/CANCER TREATED', 'CANCER UNTREATABLE']

    cervical_cancer_screening_encounter_type_id = EncounterType.find_by_name('CERVICAL CANCER SCREENING').encounter_type_id

    via_referral_concept_id = Concept.find_by_name('VIA REFERRAL').concept_id

    via_results_concept_id  = Concept.find_by_name('VIA Results').concept_id

    cryo_done_date_concept_id = Concept.find_by_name('CRYO DONE DATE').concept_id

    via_referral_outcome_concept_id = Concept.find_by_name('VIA REFERRAL OUTCOME').concept_id

    positive_cryo_concept_id = Concept.find_by_name('POSITIVE CRYO').concept_id

    patient_went_for_via_concept_id = Concept.find_by_name('PATIENT WENT FOR VIA?').concept_id

    yes_concept_id = Concept.find_by_name('YES').concept_id

    latest_patient_went_for_via_obs = begin
                                        Observation.joins([:encounter]).where(
                                          ['person_id =? AND encounter_type =? AND concept_id =?',
                                           patient.id, cervical_cancer_screening_encounter_type_id, patient_went_for_via_concept_id]
                                        ).last.answer_string.squish.upcase
                                      rescue StandardError
                                        nil
                                      end

    screening_report[:patient_went_for_via] = true if latest_patient_went_for_via_obs == 'YES'

    via_referral_answer_string = begin
                                   Observation.joins([:encounter]).where(
                                     ['person_id =? AND encounter_type =? AND concept_id =?',
                                      patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id]
                                   ).last.answer_string.squish.upcase
                                 rescue StandardError
                                   ''
                                 end

    screening_report[:todays_refferals_count] = Observation.where(['DATE(obs_datetime) =? AND concept_id =? AND value_coded =?',
                                                                   session_date, via_referral_concept_id, yes_concept_id]).select('DISTINCT(person_id)').count

    daily_referral_limit_concept = 'cervical.cancer.daily.referral.limit'
    screening_report[:daily_referral_limit] = begin
                                                GlobalProperty.find_by_property(daily_referral_limit_concept).property_value.to_i
                                              rescue StandardError
                                                1000
                                              end

    cervical_cancer_first_visit_question = patient.person.observations.recent(1).question('EVER HAD VIA?')
    screening_report[:cervical_cancer_first_visit_patient] = false unless cervical_cancer_first_visit_question.blank?
    screening_report[:via_referred] = true if via_referral_answer_string == 'YES'

    latest_via_results_obs_date = begin
                                    Observation.joins([:encounter]).where(
                                      ['person_id =? AND encounter_type =? AND concept_id =?',
                                       patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id]
                                    ).last.obs_datetime.to_date
                                  rescue StandardError
                                    nil
                                  end

    cervical_cancer_result_obs = Observation.joins([:encounter]).where(
      ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
       patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, latest_via_results_obs_date]
    ).last

    via_referral_outcome_obs = Observation.joins([:encounter]).where(
      ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
       patient.id, cervical_cancer_screening_encounter_type_id, via_referral_outcome_concept_id, latest_via_results_obs_date]
    ).last

    latest_via_referral_outcome = begin
                                    via_referral_outcome_obs.answer_string.squish.upcase
                                  rescue StandardError
                                    nil
                                  end
    screening_report[:latest_via_referral_outcome] = latest_via_referral_outcome

    screening_report[:has_via_results] = true unless cervical_cancer_result_obs.blank?

    latest_cervical_cancer_result = begin
                                       cervical_cancer_result_obs.answer_string.squish.upcase
                                    rescue StandardError
                                      nil
                                     end
    screening_report[:latest_cervical_cancer_result] = latest_cervical_cancer_result

    three_years = 365 * 3
    one_year = 365

    ############################################################################
    latest_cryo_result = Observation.joins([:encounter]).where(
      ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
       patient.id, cervical_cancer_screening_encounter_type_id, positive_cryo_concept_id, latest_via_results_obs_date]
    ).last

    unless latest_cryo_result.blank?
      cryo_result_answer = latest_cryo_result.answer_string.squish.upcase
      if cryo_result_answer == 'CRYO DELAYED'
        screening_report[:cryo_delayed] = true
        screening_report[:has_via_results] = false
      end

      if cryo_result_answer == 'LESION SIZE TOO BIG'
        screening_report[:lesion_size_too_big] = true
        obs_date = latest_cryo_result.obs_datetime.to_date
        date_gone_lesion_size_was_big = (Date.today - obs_date).to_i # Total days Between Two Dates

        if date_gone_lesion_size_was_big >= three_years
          screening_report[:lesion_size_too_big] = false
        end
      end
    end

    ############################################################################

    unless latest_cervical_cancer_result.blank?
      obs_date = cervical_cancer_result_obs.obs_datetime.to_date
      date_gone_in_days = (Date.today - obs_date).to_i # Total days Between Two Dates
      if latest_cervical_cancer_result == 'NEGATIVE'
        next_via_date = obs_date + three_years.days
        screening_report[:remaining_days] = three_years - date_gone_in_days
        if date_gone_in_days >= three_years
          screening_report[:via_referred] = false
          screening_report[:has_via_results] = false
          next_via_referral_obs = Observation.joins([:encounter]).where(
            ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
             patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date]
          ).last

          unless next_via_referral_obs.blank?
            if next_via_referral_obs.answer_string.squish.casecmp('YES').zero?
              screening_report[:via_referred] = true
            end
          end

          next_cervical_cancer_result_obs = Observation.joins([:encounter]).where(
            ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
             patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, next_via_date]
          ).last
          screening_report[:has_via_results] = true unless next_cervical_cancer_result_obs.blank?
        end
      end

      cryo_done_cancer_result_obs = Observation.joins([:encounter]).where(
        ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
         patient.id, cervical_cancer_screening_encounter_type_id, cryo_done_date_concept_id,
         latest_via_results_obs_date]
      ).last

      unless cryo_done_cancer_result_obs.blank?
        cryo_done_date = cryo_done_cancer_result_obs.answer_string.squish.to_date
        next_via_date = cryo_done_date + one_year.days
        date_gone_after_cryo_is_done = (Date.today - cryo_done_date).to_i # Total days Between Two Dates
        screening_report[:remaining_days] = one_year - date_gone_after_cryo_is_done
        if date_gone_after_cryo_is_done >= one_year
          screening_report[:via_referred] = false
          screening_report[:has_via_results] = false
          next_via_referral_obs = Observation.joins([:encounter]).where(
            ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
             patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date]
          ).last

          unless next_via_referral_obs.blank?
            if next_via_referral_obs.answer_string.squish.casecmp('YES').zero?
              screening_report[:via_referred] = true
            end
          end

          next_cervical_cancer_result_obs = Observation.joins([:encounter]).where(
            ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
             patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id,
             next_via_date]
          ).last
          screening_report[:has_via_results] = true unless next_cervical_cancer_result_obs.blank?
        end
      end

      unless latest_via_referral_outcome.blank?
        if latest_via_referral_outcome == 'NO CANCER'
          via_referral_outcome_obs_date = via_referral_outcome_obs.obs_datetime.to_date
          next_via_date = via_referral_outcome_obs_date + three_years.days
          date_gone_after_referral_outcome_is_done = (Date.today - via_referral_outcome_obs_date).to_i # Total days Between Two Dates
          screening_report[:remaining_days] = three_years - date_gone_after_referral_outcome_is_done
          screening_report[:no_cancer] = true
          screening_report[:lesion_size_too_big] = false

          if date_gone_after_referral_outcome_is_done >= three_years
            screening_report[:via_referred] = false
            screening_report[:has_via_results] = false
            screening_report[:no_cancer] = false

            next_via_referral_obs = Observation.joins([:encounter]).where(
              ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
               patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date]
            ).last

            unless next_via_referral_obs.blank?
              if next_via_referral_obs.answer_string.squish.casecmp('YES').zero?
                screening_report[:via_referred] = true
              end
            end

            next_cervical_cancer_result_obs = Observation.joins([:encounter]).where(
              ['person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?',
               patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, next_via_date]
            ).last

            unless next_cervical_cancer_result_obs.blank?
              screening_report[:has_via_results] = true
            end
          end
        end
      end
    end

    #>>>>>>>>>VIA DONE LOGIC>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    screening_report[:via_results_expired] = true

    via_done_date_answer_string = patient.person.observations.recent(1).question("VIA DONE DATE").last.answer_string.squish.to_date rescue nil
    unless via_done_date_answer_string.blank?
      #@cervical_cancer_first_visit_patient = false
      days_gone_after_via_done = (Date.today - via_done_date_answer_string).to_i #Total days Between Two Dates
      if (days_gone_after_via_done < three_years)
        screening_report[:via_referred] = true
        screening_report[:via_results_expired] = false
        screening_report[:remaining_days] = three_years - days_gone_after_via_done
      end
    end
    screening_report[:via_results_expired] = true

    via_done_date_answer_string = patient.person.observations.recent(1).question("VIA DONE DATE").last.answer_string.squish.to_date rescue nil
    unless via_done_date_answer_string.blank?
      #@cervical_cancer_first_visit_patient = false
      days_gone_after_via_done = (Date.today - via_done_date_answer_string).to_i #Total days Between Two Dates
      if (days_gone_after_via_done < three_years)
        screening_report[:via_referred] = true
        screening_report[:via_results_expired] = false
        screening_report[:remaining_days] = three_years - days_gone_after_via_done
      end
    end

    #>>>>>>>>VIA LOGIC END>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    via_referral_outcome_answers = Observation.joins([:encounter]).where(
      ["person_id =? AND encounter_type =? AND concept_id =?",
        patient.id, cervical_cancer_screening_encounter_type_id, via_referral_outcome_concept_id]
    ).collect{|o|o.answer_string.squish.upcase}

    via_referral_outcome_answers.each do |outcome|
      if terminal_referral_outcomes.include?(outcome)
        screening_report[:lesion_size_too_big] = false
        screening_report[:terminal] = true
        break
      end
    end

    screening_report
  end
end
