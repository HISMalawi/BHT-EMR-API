# frozen_string_literal: true

module TBService
    # Patients sub service.
    #
    # Basically provides ART specific patient-centric functionality
    class PatientsEngine
      include ModelUtils

      def initialize(program:)
        @program = program
      end

      # Retrieves given patient's status info.
      #
      # The info is just what you would get on a patient information
      # confirmation page in an ART application.
      def patient(patient_id, date)
        patient_summary(Patient.find(patient_id), date).full_summary
      end

      # Returns a patient's last received drugs.
      #
      # NOTE: This method is customised to return only TB.
			def patient_last_drugs_received(patient, ref_date)

				dispensing_encounter = Encounter.joins(:type).where(
          'encounter_type.name = ? AND encounter.patient_id = ?
           AND DATE(encounter_datetime) <= DATE(?)',
          'DISPENSING', patient.patient_id, ref_date
        ).order(encounter_datetime: :desc).first

        return [] unless dispensing_encounter

        # HACK: Group orders in a map first to eliminate duplicates which can
        # be created when a drug is scanned twice.
        (dispensing_encounter.observations.each_with_object({}) do |obs, drug_map|
          next unless obs.value_drug || drug_map.key?(obs.value_drug)

          order = obs.order
          next unless order&.drug_order&.quantity

          drug_map[obs.value_drug] = order.drug_order if order.drug_order.drug.tb_drug?
        end).values
      end

      # Returns patient's TB start date at current facility
      def find_patient_date_enrolled(patient)
        order = Order.joins(:encounter, :drug_order)\
                     .where(encounter: { patient: patient },
                            drug_order: { drug: Drug.tb_drugs })\
                     .order(:start_date)\
                     .first

        order&.start_date&.to_date
      end

      def visit_summary_label(patient, date)
        TBService::PatientVisitLabel.new patient, date
      end

			private

			include ModelUtils

			def patient_summary(patient, date)
				TBService::PatientSummary.new patient, date
			end

    end
  end
