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
      patients = patients_query.with_encounters(['TB_Initial', 'Diagnosis'], start_date, end_date)\
                               .with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      map_outcomes(ids, start_date, end_date)
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

      map_outcomes(patient_ids, start_date, end_date)
    end

    def new_mtb_detected_xpert (start_date, end_date)
      patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders', 'Lab Results'], start_date, end_date)\
                               .with_obs('Lab Results', 'Type of Tuberculosis', 'Multidrug-resistant TB', start_date, end_date)\
                               .with_obs('Lab Orders', 'Test requested', 'Tuberculosis smear microscopy method', start_date, end_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      map_outcomes(ids)
    end

    def relapse_bacteriologically_confirmed (start_date, end_date)
      patients = patients_query.with_obs_before('Lab Results', 'TB Status', 'Positive', start_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      map_outcomes(relapses, start_date, end_date)
    end

    def relapse_clinical_pulmonary (start_date, end_date)
      patients = patients_query.with_obs_before('Diagnosis', 'Type of tuberculosis', 'Pulmonary Tuberculosis', start_date)

      return [] if patients.empty?

      ids = patients.map(&:patient_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      map_outcomes(relapses, start_date, end_date)
    end

    def relapse_eptb (start_date, end_date)
      patients = obs_query.with_timeless('Type of Tuberculosis', 'Extrapulmonary tuberculosis (EPTB)')

      return [] if patients.empty?

      ids = patients.map(&:person_id)

      relapses = patient_states_query.relapse(ids, start_date, end_date)

      return [] if relapses.empty?

      map_outcomes(relapses, start_date, end_date)
    end

    def new_smear_positive (start_date, end_date)
      patients = patients_query.with_encounters(['TB_initial', 'Lab Orders', 'Lab Results'], start_date, end_date)

      return [] if patients.empty?

      concept = concept('Tuberculosis smear result')
      value = [
        concept('AFB Positive'),
        concept('MTB Trace'),
        concept('MTB Detected'),
        concept('TB Drug Resistance')
      ].map { |concept| concept&.concept_id }

      ids = patients.map(&:patient_id)

      smear_positive_patients = Observation.where(concept: concept,
                                                  value_coded: value,
                                                  person_id: ids,
                                                  obs_datetime: start_date..end_date)

      return [] if smear_positive_patients.empty?

      patient_ids = smear_positive_patients.map(&:person_id)

      map_outcomes(patient_ids, start_date, end_date)
    end

    def retreatment_excluding_relapse (start_date, end_date)
      type = encounter_type('Treatment')
      program = program('Program')

      patients = PatientState.includes(:patient_program)\
                             .where(state: [STATES['CURED'], STATES['TREATMENT_COMPLETE'], STATES['TREATMENT_FAILED'], STATES['DEFAULTED']])\
                             .where('patient_state.date_created < ?', start_date)

      return [] if patients.empty?

      ids = patients.map { |patient| patient.patient_program.patient_id }

      retreated = Encounter.where(patient_id: ids,
                                  program: program,
                                  encounter_datetime: start_date..end_date)

      return [] if retreated.empty?

      retreated_patients = retreated.map { |r| r.patient_id }

      map_outcomes(retreated_patients, start_date, end_date)
    end

    def hiv_positive_new_and_relapse (start_date, end_date)
      tb_initial_encounter_type = encounter_type('TB_INITIAL')
      hiv_status_concept = concept('HIV Status')
      positive_concept = concept('Positive')
      state = STATES['RELAPSE']

      encounters = Encounter.joins(:observations)\
                            .where(type: tb_initial_encounter_type,
                                   'obs.concept_id': hiv_status_concept.concept_id,
                                   'obs.value_coded': positive_concept.concept_id,
                                   'obs.obs_datetime': start_date..end_date)

      return [] if encounters.empty?

      patient_ids = encounters.map { |encounter| encounter.patient_id }

      relapsed = PatientState.includes(:patient_program)\
                             .where('patient_program.patient_id': patient_ids,
                                    state: state,
                                    'patient_state.date_created': start_date..end_date)\

      return [] if relapsed.empty?

      ids = relapsed.map { |r| r.patient_program.patient_id }

      map_outcomes(ids, start_date, end_date)
    end

    def children_aged_zero_to_four (start_date, end_date)
      min = 4.years.ago
      max = Date.today
      type = encounter_type('TB_Initial')
      children = Person.joins(:patient => :encounters)\
                       .where(birthdate: min..max,
                              encounter: { encounter_type: type , encounter_datetime: start_date..end_date })

      return [] if children.empty?

      patient_ids = children.map { |child| child.person_id }

      map_outcomes(patient_ids, start_date, end_date)
    end

    def children_aged_five_to_fourteen (start_date, end_date)
      five_years_ago = 5.years.ago
      fourteen_years_ago = 14.years.ago
      max = Date.today
      type = encounter_type('TB_Initial')
      children = Person.joins(:patient => :encounters)\
                       .where(birthdate: fourteen_years_ago..max,
                              encounter: { encounter_type: type, encounter_datetime: start_date..end_date })\
                       .or(Person.joins(:patient => :encounters)\
                                 .where(birthdate: five_years_ago..max,
                                        encounter: { encounter_type: type, encounter_datetime: start_date..end_date }))

      return [] if children.empty?

      patient_ids = children.map { |child| child.person_id }

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
      tb_number_type = patient_identifier_type('District TB Number')
      ipt_number_type = patient_identifier_type('District IPT Number')
      PatientIdentifier.where(patient_id: patient_ids,
                              type: [tb_number_type, ipt_number_type],
                              date_created: start_date..end_date)\
                       .count
                       .inspect
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