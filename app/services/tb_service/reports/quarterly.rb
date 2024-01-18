# frozen_string_literal: true

include ModelUtils

module TBService::Reports::Quarterly
  class << self
    STATES = {
      'TREATMENT_COMPLETE' => 93,
      'TREATMENT_FAILED' => 99,
      'DIED' => 94,
      'CURED' => 97,
      'DEFAULTED' => 96,
      'RELAPSE' => 168,
      'UNKNOWN' => 999,
      'CURRENTLY_IN_TREATMENT' => 92,
      'ART_TREATMENT' => 7
    }.freeze

    def new_pulmonary_clinically_diagnosed (start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      new_pulm = clinically_diagnosed_patients_query.with_pulmonary_tuberculosis(ids, start_date, end_date)

      return [] if new_pulm.empty?

      patients = new_pulm.map(&:patient_id)

      map_outcomes(patients, start_date, end_date)
    end

    def new_eptb (start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'Extrapulmonary tuberculosis (EPTB)', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      map_outcomes(persons, start_date, end_date)
    end

    def new_mtb_detected_xpert (start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'MTB Detetcted', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      map_outcomes(persons, start_date, end_date)
    end

    def new_smear_positive (start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)
      return [] if new_patients.empty?

      ids = new_patients.map(&:patient_id)

      with_mtb = obs_query.with_answer(ids, 'AFB Positive', start_date, end_date)

      return [] if with_mtb.empty?

      persons = with_mtb.map(&:person_id)

      map_outcomes(persons, start_date, end_date)
    end

    def relapse_bacteriologically_confirmed (start_date, end_date)
      patients = relapse_patients_query.bacteriologically_confirmed(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      map_outcomes(ids, start_date, end_date)
    end

    def relapse_clinical_pulmonary (start_date, end_date)
      patients = relapse_patients_query.clinical_pulmonary(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      map_outcomes(ids, start_date, end_date)
    end

    def relapse_eptb (start_date, end_date)
      patients = relapse_patients_query.eptb(start_date, end_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient['patient_id'] }

      map_outcomes(ids, start_date, end_date)
    end

    def retreatment_excluding_relapse (start_date, end_date)
      type = encounter_type('Treatment')
      program = program('TB Program')

      treated = PatientState.select('patient_program.patient_id').distinct\
                            .joins(:patient_program)\
                            .where(:patient_program => { program_id: program },
                                   :patient_state => { state: STATES['CURRENTLY_IN_TREATMENT'], date_created: start_date..end_date })

      return [] if treated.empty?

      ids = treated.map(&:patient_id)

      states = [STATES['CURED'], STATES['TREATMENT_COMPLETE'], STATES['TREATMENT_FAILED'], STATES['DEFAULTED']]

      patients = PatientState.select('patient_program.patient_id').distinct\
                             .joins(:patient_program)\
                             .where(:patient_program => { program_id: program, patient_id: ids },
                                    :patient_state => { state: states })\
                             .where('patient_state.date_created < ?', start_date)

      return [] if patients.empty?

      retreated_ids = patients.map(&:patient_id)

      map_outcomes(retreated_ids, start_date, end_date)
    end

    def hiv_positive_new_and_relapse (start_date, end_date)
      hiv_status = concept('HIV Status')
      value = concept('Positive')

      relapse = relapse_patients_query.relapse_patients(start_date, end_date)
      new_patients = patients_query.new_patients(start_date, end_date)

      return [] if relapse.empty? && new_patients.empty?

      ids = (relapse.map { |r| r['patient_id']} + new_patients.map(&:patient_id)).uniq

      positive = Observation.where(person_id: ids,
                                   concept: hiv_status,
                                   answer_concept: value)

      return [] if positive.empty?

      outcome_ids = positive.map(&:person_id)

      map_outcomes(outcome_ids, start_date, end_date)
    end

    def children_aged_zero_to_four (start_date, end_date)
      children = patients_query.age_range(0, 4, start_date, end_date)

      return [] if children.empty?

      patient_ids = children.map(&:patient_id)

      map_outcomes(patient_ids, start_date, end_date)
    end

    def children_aged_five_to_fourteen (start_date, end_date)
      children = patients_query.age_range(5, 14, start_date, end_date)

      return [] if children.empty?

      patient_ids = children.map(&:patient_id)

      map_outcomes(patient_ids, start_date, end_date)
    end

    private
    def map_outcomes (patient_ids, start_date, end_date)
      {
        'cases' => number_of_cases(patient_ids, start_date, end_date),
        'cured' => patients_with_state(patient_ids, start_date, end_date, STATES['CURED'] ),
        'complete' => patients_with_state(patient_ids, start_date, end_date, STATES['TREATMENT_COMPLETE']),
        'failed' => patients_with_state(patient_ids, start_date, end_date, STATES['TREATMENT_FAILED']),
        'defaulted' => patients_with_state(patient_ids, start_date, end_date, STATES['DEFAULTED']),
        'died' => patients_with_state(patient_ids, start_date, end_date, STATES['DIED']),
        'not_evaluated' => cases_not_evaluated(patient_ids)
      }
    end

    def number_of_cases (patient_ids, start_date, end_date)
      patient_ids.size
    end

    def patients_with_state (patient_ids, start_date, end_date, state)
      PatientState.joins(:patient_program)\
                  .where('patient_program.patient_id': patient_ids,
                          state: state,
                          end_date: nil,
                         'patient_state.date_created': start_date..end_date)\
                  .count
    end

    def cases_not_evaluated (patient_ids)
      tb_program = program('TB Program')

      ids = patient_ids.select { |id| PatientState.joins(:patient_program)\
                                                  .where('patient_program.patient_id': id,
                                                         'patient_program.program_id': tb_program.program_id)\
                                                  .blank? }

      ids.size
    end

    private
    def patients_query
      TbQueries::PatientsQuery.new.search
    end

    def patient_states_query
      TbQueries::PatientStatesQuery.new
    end

    def obs_query
      TbQueries::ObservationsQuery.new
    end

    def clinically_diagnosed_patients_query
      TbQueries::ClinicallyDiagnosedPatientsQuery.new
    end

    def relapse_patients_query
      TbQueries::RelapsePatientsQuery.new
    end
  end
end