# frozen_string_literal: true

module TbService::Reports::CaseFinding
  
  class << self
    
    AGE_GROUPS = {
      '0-4' => [0, 4],
      '5-14' => [5, 14],
      '15-24' => [15, 24],
      '25-34' => [25, 34],
      '35-44' => [35, 44],
      '45-54' => [45, 54],
      '55-64' => [55, 64],
      '65+' => [65, 200]
    }.freeze
    
    def new_pulmonary_clinically_diagnosed(start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?
    end

    def format_report(indicator:, report_data:)
      data = report_format(indicator)
      report_data&.each do |patient|
        process_patient(patient, data)
      end
      data
    end    


    def report_format(indicator)
      format_ = {
        indicator: indicator
      }
      AGE_GROUPS.each_key do |k|
        format_[k] = {
          male: [],
          female: []
        }
      end
      format_
    end

    def new_eptb(start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'Extrapulmonary tuberculosis (EPTB)', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      patients_query.ntp_age_groups(persons)
    end

    def new_mtb_detected_xpert(start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'MTB Detetcted', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      patients_query.ntp_age_groups(persons)
    end

    def new_smear_positive(start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'AFB Positive', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      patients_query.ntp_age_groups(persons)
    end

    def relapse_bacteriologically_confirmed(start_date, end_date)
      patients = relapse_patients_query.bacteriologically_confirmed(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      patients_query.ntp_age_groups(ids)
    end

    def relapse_clinical_pulmonary(start_date, end_date)
      patients = relapse_patients_query.clinical_pulmonary(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      patients_query.ntp_age_groups(ids)
    end

    def relapse_eptb(start_date, end_date)
      patients = relapse_patients_query.eptb(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      patients_query.ntp_age_groups(ids)
    end

    def treatment_failure_bacteriologically_confirmed(start_date, end_date)
      patients = obs_query.with('TB Status', 'Positive')

      return [] if patients.empty?

      ids = patients.map(&:person_id)

      fails = patient_states_query.treatment_failed(ids, start_date, end_date)

      return [] if fails.empty?

      patients_query.ntp_age_groups(fails)
    end

    def treatment_ltf_bacteriologically_confirmed(start_date, end_date)
      bact = obs_query.with('TB Status', 'Positive')

      return [] if bact.empty?

      ids = bact.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def treatment_ltf_clinically_diagnosed_pulmonary(start_date, end_date)
      with_pulm = obs_query.with('Type of Tuberculosis', 'Pulmonary Tuberculosis')

      return [] if with_pulm.empty?

      ids = patients.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def treatment_ltf_eptb(start_date, end_date)
      with_eptb = obs_query.with('Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)')

      return [] if with_eptb.empty?

      ids = with_eptb.map(&:person_id)

      ltf = patient_states_query.defaulted(ids)

      return [] if ltf.empty?

      patients_query.ntp_age_groups(ltf)
    end

    def other_previuosly_treated_bacteriologically_confirmed(start_date, end_date)
      type = encounter_type('Lab Results')
      program = program('TB Program')
      status = concept('TB Status')
      positive = concept('Positive')

      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = Encounter.select(:patient_id).distinct\
                          .joins(:observations)\
                          .where(:encounter => { encounter_type: type,
                                                 program_id: program,
                                                 patient_id: unknowns,
                                                 encounter_datetime: start_date..end_date },
                                 :obs => { concept_id: status, value_coded: positive })

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def other_previuosly_treated_clinical_pulmonary(start_date, end_date)
      type = encounter_type('Diagnosis')
      program = program('TB Program')
      status = concept('TB Status')
      positive = concept('Positive')

      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = Encounter.select(:patient_id).distinct\
                          .joins(:observations)\
                          .where(:encounter => { encounter_type: type,
                                                 program_id: program,
                                                 patient_id: unknowns,
                                                 encounter_datetime: start_date..end_date },
                                 :obs => { concept_id: status, value_coded: positive })

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def other_previuosly_treated_eptb(start_date, end_date)
      type = encounter_type('Lab Results')
      program = program('TB Program')
      status = concept('Type of Tuberculosis')
      tb_type = concept('Extrapulmonary Tuberculosis (EPTB)')

      unknowns = patient_states_query.other_previous_treatment()

      return [] if unknowns.empty?

      patients = Encounter.select(:patient_id).distinct\
                          .joins(:observations)\
                          .where(:encounter => { encounter_type: type,
                                                 program_id: program,
                                                 patient_id: unknowns,
                                                 encounter_datetime: start_date..end_date },
                                 :obs => { concept_id: status, value_coded: tb_type })

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_bacteriological(start_date, end_date)
      patients = patients_query.with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)
                               .without_encounters(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_pulmonary_clinical(start_date, end_date)
      patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', start_date,
                                         end_date)\
                               .without_encounters(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def unknown_previous_treatment_history_eptb(start_date, end_date)
      patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)',
                                         start_date, end_date)\
                               .without_encounters(['Treatment'])

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(ids)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination(start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders'], start_date, end_date)\
                               .without_encounters(['Lab Results'], start_date, end_date)

      return [] if patients.empty?

      patient_ids = patients.map(&:patient_id)

      patients_query.ntp_age_groups(patient_ids)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination(start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders', 'Lab Results'], start_date, end_date)\
                               .without_encounters(['Treatment'], start_date, end_date)\
                               .with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)
    end

    def unknown_previous_treatment_history_eptb(start_date, end_date)
      query = tx_history_query.ref(start_date, end_date)
      query.eptb(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination(start_date, end_date)
      presumptives_query.undergoing_bacteriological_examination(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination_via_xpert(start_date, end_date)
      presumptives_query.via_xpert(start_date, end_date)
    end

    def patients_with_presumptive_tb_undergoing_bacteriological_examination_via_microscopy(start_date, end_date)
      presumptives_query.via_microscopy(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination(start_date, end_date)
      presumptives_query.with_positive_bacteriological_examination(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination_via_xpert(start_date, end_date)
      presumptives_query.via_xpert_pos(start_date, end_date)
    end

    def patients_with_presumptive_tb_with_positive_bacteriological_examination_via_microscopy(start_date, end_date)
      presumptives_query.via_microscopy_pos(start_date, end_date)
    end
    def patients_query
      TbService::TbQueries::PatientsQuery.new.search
    end
    
    def presumptives_query
      TbService::TbQueries::PresumptivesQuery.new
    end

    def patient_states_query
      TbService::TbQueries::PatientStatesQuery.new
    end

    def obs_query
      TbService::TbQueries::ObservationsQuery.new
    end

    def clinically_diagnosed_patients
      TbService::TbQueries::ClinicallyDiagnosedPatientsQuery.new
    end

    def relapse_patients_query
      TbService::TbQueries::RelapsePatientsQuery.new
    end
  end
end