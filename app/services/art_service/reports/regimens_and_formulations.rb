# frozen_string_literal: true

module ARTService
  module Reports
    # Retrieve patients in a particular regimen and formulation.
    class RegimensAndFormulations
      attr_reader :start_date, :end_date, :regimen, :formulation

      def initialize(start_date:, end_date:, regimen: nil, formulation: 'tablets', **_kwargs)
        raise InvalidParameterError, 'regimen is required' unless regimen

        unless %w[granules tablets pellets].include?(formulation)
          raise InvalidParameterError, "Invalid formalation: #{formulation}"
        end

        @start_date = start_date
        @end_date = end_date
        @formulation = formulation
        @regimen = regimen
      end

      def find_report
        patients
      end

      def patients
        patients_with_prescriptions.each_with_object([]) do |patient, matching_patients|
          prescribed_drugs = drugs_prescribed_to_patient(patient.patient_id, patient.prescription_date).map(&:drug_id)
          non_matching_drugs = Set.new(drugs) - prescribed_drugs

          next unless non_matching_drugs.empty?

          demographics = patient_demographics(patient.patient_id, patient.prescription_date)

          matching_patients << {
            patient_id: demographics.patient_id,
            arv_number: demographics.arv_number,
            birthdate: demographics.birthdate,
            gender: demographics.gender,
            weight: demographics.weight
          }
        end
      end

      private

      TABLET_REGIMENS = {
        '0A' => [969, 22],
        '0P' => [1044, 968],
        '2A' => [731],
        '2P' => [732],
        '4A' => [39, 11],
        '4P' => [736, 30],
        '5A' => [735],
        '6A' => [734, 22],
        '7A' => [734, 932],
        '8A' => [39, 932],
        '9A' => [969, 73],
        '9P' => [1044, 74],
        '10A' => [734, 73],
        '11A' => [39, 73],
        '11P' => [736, 74],
        '12A' => [982, 977, 976],
        '13A' => [983],
        '14A' => [984, 982],
        '14P' => [736, 982],
        '15A' => [969, 982],
        '15P' => [1044, 982],
        '16A' => [969, 954],
        '16P' => [1044, 1043],
        '17A' => [969, 11],
        '17P' => [1044, 30]
      }.freeze

      GRANULES_REGIMENS = {
        '9P' => [1044, 1045],
        '11P' => [736, 1045]
      }.freeze

      PELLETS_REGIMENS = {
        '9P' => [1044, 979],
        '11P' => [736, 979]
      }.freeze

      REGIMENS_BY_FORMULATION = {
        'granules' => GRANULES_REGIMENS,
        'pellets' => PELLETS_REGIMENS,
        'tablets' => TABLET_REGIMENS
      }.freeze

      # Returns drugs in selected regimen and formulation
      def drugs
        REGIMENS_BY_FORMULATION[formulation][regimen]
      end

      def patients_with_prescriptions
        return [] if drugs.nil?

        DrugOrder.select('orders.patient_id AS patient_id, MAX(start_date) AS prescription_date')
                 .joins(:order)
                 .where(quantity: 1..Float::INFINITY, drug_inventory_id: drugs)
                 .merge(treatment_orders)
                 .group('orders.patient_id')
      end

      # Returns all orders in treatment encounter of HIV program
      def treatment_orders
        Order.joins(:encounter)
             .where(start_date: start_date..end_date)
             .merge(treatment_encounter)
             .or(Order.joins(:encounter)
                      .where(auto_expire_date: start_date..end_date)
                      .merge(treatment_encounter))
             .or(Order.joins(:encounter)
                      .where('start_date < ? AND auto_expire_date > ?', start_date, end_date)
                      .merge(treatment_encounter))
      end

      def treatment_encounter
        Encounter.where(encounter_type: EncounterType.find_by_name('Treatment'),
                        program_id: Constants::PROGRAM_ID)
      end

      # Returns drugs prescribed to patient on given day
      def drugs_prescribed_to_patient(patient_id, prescription_date)
        DrugOrder.select('drug_order.drug_inventory_id AS drug_id')
                 .joins(:order)
                 .where(quantity: 1..Float::INFINITY, drug_inventory_id: drugs)
                 .merge(Order.joins(:encounter)
                             .where(patient_id: patient_id, start_date: prescription_date)
                             .merge(treatment_encounter))
      end

      def patient_demographics(patient_id, prescription_date)
        Person.find_by_sql(
          <<~SQL
            SELECT person.person_id AS patient_id, patient_identifier.identifier AS arv_number,
                   person.birthdate AS birthdate, person.gender AS gender, obs.value_numeric AS weight
            FROM person
            LEFT JOIN patient_identifier ON patient_identifier.patient_id = person.person_id
                                         AND patient_identifier.identifier_type = #{arv_number_type_id}
                                         AND patient_identifier.voided = 0
            LEFT JOIN obs ON obs.person_id = person.person_id
                          AND obs.concept_id = #{weight_concept_id}
                          AND obs.obs_datetime = (
                            SELECT MAX(obs_datetime) FROM obs
                            WHERE person_id = #{patient_id}
                              AND concept_id = #{weight_concept_id}
                              AND obs_datetime <= '#{prescription_date}'
                              AND voided = 0
                          ) AND obs.voided = 0
            WHERE person.person_id = #{patient_id}
          SQL
        ).first
      end

      def patient_recent_weight(patient_id, as_of)
        Observation.select(:value_numeric)
                   .where(concept_id: ConceptName.find_by_name('Weight (kg)').concept_id,
                          person_id: patient_id)
                   .where('obs_datetime < ? AND value_numeric IS NOT NULL', as_of)
                   .order(obs_datetime: :desc)
                   .first
                   &.value_numeric
      end

      def weight_concept_id
        @weight_concept_id ||= ConceptName.find_by_name('Weight (kg)').concept_id
      end

      def arv_number_type_id
        @arv_number_id ||= PatientIdentifierType.find_by_name('ARV Number').id
      end
    end
  end
end
