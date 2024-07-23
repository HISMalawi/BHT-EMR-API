# frozen_string_literal: true

module TbService
  module Reports
    module CaseFinding
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
          [] if new_patients.empty?
        end

        def format_report(indicator:, report_data:, **_kwargs)
          data = report_format(indicator)
          report_data&.each do |patient|
            process_patient(patient, data)
          end
          data
        end

        def process_patient(patient, data)
          age = patient.age
          gender = patient.gender == 'M' ? :male : :female
          age_group = AGE_GROUPS.keys.find { |k| age.between?(*AGE_GROUPS[k]) }
          data[age_group][gender] << patient.id
          data
        end

        def report_format(indicator)
          format_ = {
            indicator:
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
          new_patients = obs_query.new_patients(start_date, end_date)
          return [] if new_patients.empty?

          ids = new_patients.map(&:person_id)

          with_mtb = obs_query.with_answer(ids, 'Extrapulmonary tuberculosis (EPTB)', start_date, end_date)

          return [] if with_mtb.empty?

          Patient.where(patient_id: with_mtb.map(&:person_id))
        end

        def new_mtb_detected_xpert(start_date, end_date)
          new_patients = obs_query.new_patients(start_date, end_date)
          return [] if new_patients.empty?

          ids = new_patients.map(&:person_id)

          with_mtb = obs_query.with_answer(ids, 'MTB Detetcted', start_date, end_date)

          return [] if with_mtb.empty?

          Patient.where(patient_id: with_mtb.map(&:person_id))
        end

        def new_smear_positive(start_date, end_date)
          new_patients = obs_query.new_patients(start_date, end_date)
          return [] if new_patients.empty?

          ids = new_patients.map(&:person_id)

          with_mtb = obs_query.with_answer(ids, 'AFB Positive', start_date, end_date)

          return [] if with_mtb.empty?

          Patient.where(patient_id: with_mtb.map(&:person_id))
        end

        def relapse_bacteriologically_confirmed(start_date, end_date)
          states = {
            RX: 92, # in treatment
            RP: 168, # relapse
            CR: 97 # cured
          }.freeze

          type = encounter_type('Lab Results').encounter_type_id
          value = concept('Positive').concept_id
          program = program('TB Program')
          ActiveRecord::Base.connection.select_all(
            <<~SQL
              SELECT States.patient_id
              FROM
              (
                SELECT DISTINCT(patient_id), patient_state.date_created
                FROM
                  patient JOIN patient_program USING(patient_id)
                JOIN patient_state USING(patient_program_id)
                WHERE patient_state.state = '#{states[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
              ) AS States
              JOIN
              (
                SELECT DISTINCT(person_id), obs_datetime
                FROM encounter JOIN obs USING(encounter_id)
                WHERE
                  value_coded = '#{value}' AND encounter_datetime BETWEEN "#{start_date}"
                  AND "#{end_date}" AND encounter_type = '#{type}' AND encounter.voided = 0
                  AND encounter.program_id = '#{program.id}'
              ) AS BactConfirmed
              ON States.patient_id = BactConfirmed.person_id
              WHERE BactConfirmed.obs_datetime <= States.date_created;
            SQL
          )
        end

        def relapse_clinical_pulmonary(start_date, end_date)
          states = {
            RX: 92, # in treatment
            RP: 168, # relapse
            CR: 97 # cured
          }.freeze

          type = encounter_type('Diagnosis').encounter_type_id
          value = concept('Positive').concept_id
          program = program('TB Program')
          ActiveRecord::Base.connection.select_all(
            <<~SQL
              SELECT States.patient_id
              FROM
              (
                SELECT DISTINCT(patient_id), patient_state.date_created
                FROM
                  patient JOIN patient_program USING(patient_id)
                JOIN patient_state USING(patient_program_id)
                WHERE patient_state.state = '#{states[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
              ) AS States
              JOIN
              (
                SELECT DISTINCT(person_id), obs_datetime
                FROM encounter JOIN obs USING(encounter_id)
                WHERE
                  value_coded = '#{value}' AND encounter_datetime BETWEEN "#{start_date}"
                  AND "#{end_date}" AND encounter_type = '#{type}' AND encounter.voided = 0
                  AND encounter.program_id = #{program.id}
              ) AS ClinicConfirmed
              ON States.patient_id = ClinicConfirmed.person_id
              WHERE ClinicConfirmed.obs_datetime <= States.date_created;
            SQL
          )
        end

        def relapse_eptb(start_date, end_date)
          states = {
            RX: 92, # in treatment
            RP: 168, # relapse
            CR: 97 # cured
          }.freeze
          value = concept('Extrapulmonary tuberculosis (EPTB) ')
          ActiveRecord::Base.connection.select_all(
            <<~SQL
              SELECT States.patient_id
              FROM
              (
                SELECT DISTINCT(patient_id), patient_state.date_created
                FROM
                  patient JOIN patient_program USING(patient_id)
                JOIN patient_state USING(patient_program_id)
                WHERE patient_state.state = '#{states[:RP]}' AND patient_state.end_date IS NULL AND patient_state.voided = 0
              ) AS States
              JOIN
              (
                SELECT DISTINCT(person_id), obs_datetime
                FROM obs
                WHERE value_coded = '#{value}' AND obs_datetime BETWEEN "#{start_date}" AND "#{end_date}" AND obs.voided = 0
              ) AS Eptb
              ON States.patient_id = Eptb.person_id
              WHERE Eptb.obs_datetime <= States.date_created;
            SQL
          )
        end

        def treatment_failure_bacteriologically_confirmed(start_date, end_date)
          patients = obs_query.with('TB Status', 'Positive')

          return [] if patients.empty?

          ids = patients.map(&:person_id)

          fails = patient_states_query.treatment_failed(ids, start_date, end_date)

          return [] if fails.empty?

          Patient.where(patient_id: fails.map(&:patient_id))
        end

        def treatment_ltf_bacteriologically_confirmed(_start_date, _end_date)
          bact = obs_query.with('TB Status', 'Positive')

          return [] if bact.empty?

          ids = bact.map(&:person_id)

          ltf = patient_states_query.defaulted(ids)

          return [] if ltf.empty?

          Patient.where(patient_id: ltf.map(&:patient_id))
        end

        def treatment_ltf_clinically_diagnosed_pulmonary(_start_date, _end_date)
          with_pulm = obs_query.with('Type of Tuberculosis', 'Pulmonary Tuberculosis')

          return [] if with_pulm.empty?

          ids = patients.map(&:person_id)

          ltf = patient_states_query.defaulted(ids)

          return [] if ltf.empty?

          Patient.where(patient_id: ltf.map(&:patient_id))
        end

        def treatment_ltf_eptb(_start_date, _end_date)
          with_eptb = obs_query.with('Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)')

          return [] if with_eptb.empty?

          ids = with_eptb.map(&:person_id)

          ltf = patient_states_query.defaulted(ids)

          return [] if ltf.empty?

          Patient.where(patient_id: ltf.map(&:patient_id))
        end

        def other_previously_treated_bacteriologically_confirmed(start_date, end_date)
          type = encounter_type('Lab Results')
          program = program('TB Program')
          status = concept('TB Status')
          positive = concept('Positive')

          unknowns = patient_states_query.other_previous_treatment

          return [] if unknowns.empty?

          patients = Encounter.select(:patient_id).distinct\
                              .joins(:observations)\
                              .where(encounter: { encounter_type: type,
                                                  program_id: program,
                                                  patient_id: unknowns,
                                                  encounter_datetime: start_date..end_date },
                                     obs: { concept_id: status, value_coded: positive })

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def other_previously_treated_clinical_pulmonary(start_date, end_date)
          type = encounter_type('Diagnosis')
          program = program('TB Program')
          status = concept('TB Status')
          positive = concept('Positive')

          unknowns = patient_states_query.other_previous_treatment

          return [] if unknowns.empty?

          patients = Encounter.select(:patient_id).distinct\
                              .joins(:observations)\
                              .where(encounter: { encounter_type: type,
                                                  program_id: program,
                                                  patient_id: unknowns,
                                                  encounter_datetime: start_date..end_date },
                                     obs: { concept_id: status, value_coded: positive })

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def other_previously_treated_eptb(start_date, end_date)
          type = encounter_type('Lab Results')
          program = program('TB Program')
          status = concept('Type of Tuberculosis')
          tb_type = concept('Extrapulmonary Tuberculosis (EPTB)')

          unknowns = patient_states_query.other_previous_treatment

          return [] if unknowns.empty?

          patients = Encounter.select(:patient_id).distinct\
                              .joins(:observations)\
                              .where(encounter: { encounter_type: type,
                                                  program_id: program,
                                                  patient_id: unknowns,
                                                  encounter_datetime: start_date..end_date },
                                     obs: { concept_id: status, value_coded: tb_type })

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def unknown_previous_treatment_history_bacteriological(start_date, end_date)
          patients = patients_query.with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)
                                   .without_encounters(['Treatment'])

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def unknown_previous_treatment_history_pulmonary_clinical(start_date, end_date)
          patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Pulmonary Tuberculosis', start_date,
                                             end_date)\
                                   .without_encounters(['Treatment'])

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def unknown_previous_treatment_history_eptb(start_date, end_date)
          patients = patients_query.with_obs('Diagnosis', 'Type of Tuberculosis', 'Extrapulmonary Tuberculosis (EPTB)',
                                             start_date, end_date)\
                                   .without_encounters(['Treatment'])

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def patients_with_presumptive_tb_undergoing_bacteriological_examination(start_date, end_date)
          patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders'], start_date, end_date)\
                                   .without_encounters(['Lab Results'], start_date, end_date)

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
        end

        def patients_with_presumptive_tb_with_positive_bacteriological_examination(start_date, end_date)
          patients = patients_query.with_encounters(['TB_Initial', 'Lab Orders', 'Lab Results'], start_date, end_date)\
                                   .without_encounters(['Treatment'], start_date, end_date)\
                                   .with_obs('Lab Results', 'TB Status', 'Positive', start_date, end_date)

          return [] if patients.empty?

          Patient.where(patient_id: patients.map(&:patient_id))
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
  end
end
