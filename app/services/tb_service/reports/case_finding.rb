# frozen_string_literal: true

module TBService::Reports::CaseFinding
  class << self
    def new_pulmonary_clinically_diagnosed (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Diagnosis'], start_date, end_date)\
                               .with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def new_mtb_detected_xpert (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders', 'Lab Results'], start_date, end_date)

      ids = patients.map(&:patient_id)

      sample_one = concept('Sample One GeneXpert Result')
      sample_two = concept('Sample Two GeneXpert Result')
      value = concept('MTB Detetcted')

      ids = patients.map(&:patient_id)

      mtb_detected_patients = Observation.where(concept: [sample_one, sample_two],
                                                answer_concept: value,
                                                person_id: ids,
                                                obs_datetime: start_date..end_date)

      return [] if mtb_detected_patients.empty?

      mtb_ids = mtb_detected_patients.map(&:person_id)

      patients_query.ntp_age_groups(mtb_ids)
    end

    def new_smear_positive (start_date, end_date)
      patients = patients_query.with_encounters(['TB_initial', 'Lab Orders', 'Lab Results'], start_date, end_date)

      return [] if patients.empty?

      sample_one = concept('Sample One Microscopy Result')
      sample_two = concept('Sample Two Microscopy Result')
      value = concept('AFB Positive')

      ids = patients.map(&:patient_id)

      smear_positive_patients = Observation.where(concept: [sample_one, sample_two],
                                                  answer_concept: value,
                                                  person_id: ids,
                                                  obs_datetime: start_date..end_date)

      return [] if smear_positive_patients.empty?

      patient_ids = smear_positive_patients.map(&:person_id)

      patients_query.ntp_age_groups(patient_ids)
    end

    def new_eptb (start_date, end_date)
      patients = patients_query.or_with_encounters(['TB_Initial', 'Lab Results'], ['TB_Initial', 'Diagnosis'], start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      concept = concept('Type of tuberculosis')
      value = concept('Extrapulmonary tuberculosis (EPTB)')

      eptb_patients = Observation.where(concept: concept,
                                        answer_concept: value,
                                        person_id: ids,
                                        obs_datetime: start_date..end_date)

      return [] if eptb_patients.empty?

      patient_ids = eptb_patients.map(&:person_id)

      patients_query.ntp_age_groups(patient_ids)
    end

    def relapse_bacteriologically_confirmed (start_date, end_date)
      patients = patients_query.with_obs_before('Lab Results', 'TB Status', 'Positive', start_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      patients_query.ntp_age_groups(relapses)
    end

    def relapse_clinical_pulmonary (start_date, end_date)
      patients = patients_query.with_obs_before('Diagnosis', 'Type of tuberculosis', 'Pulmonary Tuberculosis', start_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      patients_query.ntp_age_groups(relapses)
    end

    def relapse_eptb (start_date, end_date)
      patients = obs_query.with_timeless('Type of Tuberculosis', 'Extrapulmonary tuberculosis (EPTB)')

      return [] if patients.empty?

      ids = patients.map(&:person_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      patients_query.ntp_age_groups(relapses)
    end

    def treatment_failure_bacteriologically_confirmed (start_date, end_date)
      patients = obs_query.with_timeless('TB Status', 'Positive')

      return [] if patients.empty?

      ids = patients.map(&:person_id)

      fails = patient_states_query.treatment_failed(ids, start_date, end_date)

      return [] if fails.empty?

      patients_query.ntp_age_groups(fails)
    end

    def treatment_ltf_bacteriologically_confirmed (start_date, end_date)
      bact = obs_query.with_timeless('TB Status', 'Positive')

      return [] if bact.empty?

      ids = bact.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def treatment_ltf_clinically_diagnosed_pulmonary (start_date, end_date)
      with_pulm = obs_query.with_timeless('Type of Tuberculosis', 'Pulmonary Tuberculosis')

      return [] if with_pulm.empty?

      ids = patients.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def treatment_ltf_eptb (start_date, end_date)
      with_eptb = obs_query.with_timeless('Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)')

      return [] if with_eptb.empty?

      ids = with_eptb.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def other_previuosly_treated_bacteriologically_confirmed (start_date, end_date)
      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = patients_query.some_with_obs('Lab Results', 'TB Status', 'Positive', unknowns)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def other_previuosly_treated_clinical_pulmonary (start_date, end_date)
      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = patients_query.some_with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', unknowns)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def other_previuosly_treated_eptb (start_date, end_date)
      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = patients_query.some_with_obs('Diagnosis', 'Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)', unknowns)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_bacteriological (start_date, end_date)
      patients = patients_query.with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)
                               .without_encounters_ever(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_pulmonary_clinical (start_date, end_date)
      patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', start_date, end_date)\
                               .without_encounters_ever(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_eptb (start_date, end_date)
      patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)', start_date, end_date)\
                               .without_encounters_ever(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders'], start_date, end_date)\
                               .without_encounters(['Lab Results'], start_date, end_date)

      return [] if patients.empty?

      patient_ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(patient_ids)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders', 'Lab Results'], start_date, end_date)\
                               .without_encounters(['Treatment'], start_date, end_date)\
                               .with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    private
    def patients_query
      TBQueries::PatientsQuery.new.search
    end

    def patient_states_query
      TBQueries::PatientStatesQuery.new
    end

    def obs_query
      TBQueries::ObservationsQuery.new
    end
  end
end