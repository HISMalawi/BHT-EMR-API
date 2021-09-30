# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      class ViralLoadCoverage
        attr_reader :start_date, :end_date

        include Utils

        def initialize(**params)
          @start_date = params[:start_date]&.to_date
          raise InvalidParameterError, 'start_date is required' unless @start_date

          @end_date = params[:end_date]&.to_date || @start_date + 12.months
          raise InvalidParameterError, "start_date can't be greater than end_date" if @start_date > @end_date

          @rebuild_outcomes = params.fetch(:rebuild_outcomes, 'true')&.casecmp?('true')
          @type = params.fetch(:application, 'poc')
        end

        def find_report
          report = init_report

          case @type
          when /poc/i then build_poc_report(report)
          when /emastercard/i then build_emastercard_report(report)
          else raise InvalidParameterError, "Report type must be one of [poc, emastercard] not #{@type}"
          end

          report
        end

        private

        def build_poc_report(report)
          load_patients_into_report(report, :tx_curr, find_patients_alive_and_on_art)
          load_patients_into_report(report, :due_for_vl, find_patients_due_for_viral_load)
          load_patients_into_report(report, :tested, find_patients_tested_for_viral_load)
          load_patients_into_report(report, :high_vl, find_patients_with_high_viral_load)
          load_patients_into_report(report, :low_vl, find_patients_with_low_viral_load)
        end

        def build_emastercard_report(report)
          load_patients_into_report(report, :tx_curr, find_patients_alive_and_on_art)
          load_patients_into_report(report, :high_vl, find_emastercard_patients_with_high_viral_load)
          load_patients_into_report(report, :low_vl, find_emastercard_patients_with_low_viral_load)
        end

        def init_report
          pepfar_age_groups.each_with_object({}) do |age_group, report|
            report[age_group] = { tx_curr: [], due_for_vl: [], tested: [], high_vl: [], low_vl: [] }
          end
        end

        def load_patients_into_report(report, sub_report, patients)
          patients.each do |patient|
            report[patient.age_group][sub_report] << {
              patient_id: patient.patient_id,
              arv_number: patient.arv_number,
              gender: patient.gender,
              birthdate: patient.birthdate
            }
          end
        end

        def find_patients_alive_and_on_art
          patients = PatientsAliveAndOnTreatment
                     .new(start_date: start_date, end_date: end_date, outcomes_definition: 'pepfar', rebuild_outcomes: @rebuild_outcomes)
                     .query
          pepfar_patient_drilldown_information(patients, end_date)
        end

        ##
        # Selects patients who are due for viral load
        def find_patients_due_for_viral_load
          overdue_patients = find_patients_with_overdue_viral_load
          due_for_initial_viral_load = find_patients_due_for_initial_viral_load # .where.not(patient: overdue_patients)

          Rails.logger.debug do
            overdue_patients_count = overdue_patients.collect(&:patient_id).size
            due_for_initial_viral_load_count = due_for_initial_viral_load.collect(&:patient_id).size

            "VL Coverage: overdue: #{overdue_patients_count}, Due for initial 6 months viral load: #{due_for_initial_viral_load_count}"
          end

          overdue_patients + due_for_initial_viral_load
        end

        ##
        # Selects patients whose last viral load should have expired before the end of the reporting period.
        #
        # Patients returned by this aren't necessarily due for viral load, they may have
        # their current milestone delayed. So extra processing on the patients is required
        # to filter out the patients with delayed milestones.
        def find_patients_with_overdue_viral_load
          Lab::LabOrder.joins(:tests)
                       .joins("INNER JOIN temp_patient_outcomes AS outcomes ON outcomes.patient_id = orders.patient_id AND outcomes.cum_outcome = 'On Antiretrovirals'")
                       .joins('INNER JOIN person ON person.person_id = orders.patient_id AND person.voided = 0')
                       .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = orders.patient_id AND patient_identifier.voided = 0')
                       .where(concept: ConceptName.where(name: 'Blood').select(:concept_id),
                              patient_identifier: { identifier_type: pepfar_patient_identifier_type })
                       .where('start_date < ?', end_date)
                       .merge(find_viral_load_tests)
                       .group(:patient_id)
                       .select("orders.patient_id,
                                person.birthdate,
                                person.gender,
                                cohort_disaggregated_age_group(person.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                                (MAX(start_date) + INTERVAL 12 MONTH) AS viral_load_due_date,
                                patient_identifier.identifier AS arv_number")
                       .having('viral_load_due_date < ?', end_date)
        end

        ##
        # Returns all patients that have been on ART for at least 6 months and have never had a Viral Load.
        def find_patients_due_for_initial_viral_load
          Order.joins(:order_type, :drug_order)
               .joins('INNER JOIN temp_patient_outcomes AS outcomes USING (patient_id)')
               .joins('INNER JOIN person ON person.person_id = orders.patient_id AND person.voided = 0')
               .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = orders.patient_id AND patient_identifier.voided = 0')
               .merge(OrderType.where(name: 'Drug order'))
               .merge(DrugOrder.where('drug_order.quantity > 0'))
               .where(concept: ConceptSet.find_members_by_name('Antiretroviral drugs').select(:concept_id),
                      patient_identifier: { identifier_type: pepfar_patient_identifier_type })
               .where('outcomes.cum_outcome LIKE ?', 'On antiretrovirals')
               .where.not(patient_id: find_patients_with_viral_load.collect(&:patient_id))
               .where('start_date < DATE(?)', end_date)
               .group(:patient_id)
               .select("orders.patient_id,
                        person.birthdate,
                        person.gender,
                        (MIN(start_date) + INTERVAL 6 MONTH) AS viral_load_due_date,
                        cohort_disaggregated_age_group(person.birthdate, DATE(#{ActiveRecord::Base.connection.quote(end_date)})) AS age_group,
                        patient_identifier.identifier AS arv_number")
               .having('viral_load_due_date < ?', end_date)
        end

        ##
        # Find all patients that are on treatment with at least one VL before end of reporting period.
        def find_patients_with_viral_load
          Lab::LabOrder.joins('INNER JOIN temp_patient_outcomes AS outcomes USING (patient_id)')
                       .where('start_date < DATE(?)', end_date)
                       .where('outcomes.cum_outcome LIKE ?', 'On Antiretrovirals')
                       .group(:patient_id)
                       .select('orders.patient_id')
        end

        ##
        # Returns all patients that have been tested for viral load during the reporting period.
        def find_patients_tested_for_viral_load
          patients = find_patients_with_viral_load.where('start_date >= DATE(?)', start_date)
          pepfar_patient_drilldown_information(patients, end_date)
        end

        ##
        # Returns a Relation of all viral load tests.
        def find_viral_load_tests
          Lab::LabTest.where(value_coded: ConceptName.where(name: 'Viral load').select(:concept_id))
        end

        ##
        # Returns all patients with a viral load of at least 1000 in reporting period.
        def find_patients_with_high_viral_load
          viral_load = ConceptName.select(:concept_id).find_by!(name: 'Viral load').concept_id

          find_viral_load_tests
            .joins(result: [:children])
            .joins('INNER JOIN person ON person.person_id = obs.person_id AND person.voided = 0')
            .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.voided = 0')
            .where('children_obs.concept_id = ? AND children_obs.value_numeric >= 1000', viral_load)
            .where(obs_datetime: start_date..end_date, patient_identifier: { identifier_type: pepfar_patient_identifier_type })
            .group(:person_id)
            .select("obs.person_id AS patient_id,
                     patient_identifier.identifier AS arv_number,
                     person.birthdate,
                     person.gender,
                     cohort_disaggregated_age_group(person.birthdate, #{ActiveRecord::Base.connection.quote(end_date)}) AS age_group")
        end

        ##
        # Returns all patients with a viral load below 1000 or < LDL in reporting period.
        def find_patients_with_low_viral_load
          viral_load = ConceptName.select(:concept_id).find_by!(name: 'Viral load').concept_id

          find_viral_load_tests
            .joins(result: [:children])
            .joins('INNER JOIN person ON person.person_id = obs.person_id AND person.voided = 0')
            .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = obs.person_id AND patient_identifier.voided = 0')
            .where('children_obs.concept_id = ?', viral_load)
            .where("children_obs.value_numeric < 1000 OR (children_obs.value_modifier = '<' AND children_obs.value_text = 'LDL')")
            .where(obs_datetime: start_date..end_date, patient_identifier: { identifier_type: pepfar_patient_identifier_type })
            .group(:person_id)
            .select("obs.person_id AS patient_id,
                     patient_identifier.identifier AS arv_number,
                     person.birthdate,
                     person.gender,
                     cohort_disaggregated_age_group(person.birthdate, #{ActiveRecord::Base.connection.quote(end_date)}) AS age_group")
        end

        def find_emastercard_patients_with_low_viral_load
          Observation.joins(order: [:order_type])
                     .joins('INNER JOIN temp_patient_outcomes ON temp_patient_outcomes.patient_id = obs.person_id')
                     .joins('INNER JOIN person ON person.person_id = obs.person_id AND person.voided = 0')
                     .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = obs.person_id AND patient_identifier.voided = 0')
                     .where(concept: ConceptName.where(name: 'Viral load').select(:concept_id),
                            orders: { order_type: { name: 'Lab' } },
                            temp_patient_outcomes: { cum_outcome: 'On antiretrovirals' })
                     .where("obs.value_numeric < 1000 AND obs.value_modifier IN ('=', '<')")
                     .group(:person_id)
                     .select("obs.person_id AS patient_id,
                              patient_identifier.identifier AS arv_number,
                              person.birthdate,
                              person.gender,
                              cohort_disaggregated_age_group(person.birthdate, #{ActiveRecord::Base.connection.quote(end_date)}) AS age_group")
        end

        def find_emastercard_patients_with_high_viral_load
          Observation.joins(order: [:order_type])
                     .joins('INNER JOIN temp_patient_outcomes ON temp_patient_outcomes.patient_id = obs.person_id')
                     .joins('INNER JOIN person ON person.person_id = obs.person_id AND person.voided = 0')
                     .joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = obs.person_id AND patient_identifier.voided = 0')
                     .where(concept: ConceptName.where(name: 'Viral load').select(:concept_id),
                            orders: { order_type: { name: 'Lab' } },
                            temp_patient_outcomes: { cum_outcome: 'On antiretrovirals' })
                     .where("(obs.value_modifier = '=' AND obs.value_numeric >= 1000) OR (obs.value_modifier = '>' AND value_numeric IS NOT NULL)")
                     .group(:person_id)
                     .select("obs.person_id AS patient_id,
                              patient_identifier.identifier AS arv_number,
                              person.birthdate,
                              person.gender,
                              cohort_disaggregated_age_group(person.birthdate, #{ActiveRecord::Base.connection.quote(end_date)}) AS age_group")
        end
      end
    end
  end
end
