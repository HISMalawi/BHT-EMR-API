# frozen_string_literal: true

module TbService
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

    # assess whether a patient must go for a lab order
    def due_lab_order?(patient:)
      program_start_date = find_patient_date_enrolled(patient)
      return false unless program_start_date

      days = (Date.today - program_start_date).to_i
      falls_within_ordering_period?(days: days, tolerance: 5) && no_orders_done?(patient: patient, time: 5.days.ago)
    end

    def no_orders_done?(patient:, time:)
      lab_order = encounter_type('Lab Orders')
      Encounter.where('patient_id = ? AND program_id = ? AND encounter_datetime >= ?',\
                      patient.patient_id, @program.program_id, time).blank?
    end

    def falls_within_ordering_period?(days:, tolerance:)
      # a lab order is supposed to be done after 56, 84, 140 and 260 days
      intervals = [56, 84, 140, 260]

      # the patient may come earlier or later so a tolerance must be added
      intervals.each do |interval|
        return true if (days.between?(interval - tolerance, interval + tolerance))
      end
      false
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
      TbService::PatientVisitLabel.new patient, date
    end

    def transfer_out_label(patient, date)
      TbService::PatientTransferOutLabel.new patient, date
    end

    def medication_side_effects(patient, date)
      service = TbService::PatientSideEffect.new(patient, date)
      service.side_effects
    end

    def tb_negative_minor(patient)
      status_concept = concept('TB status').concept_id
      positive_concept = concept('Negative').concept_id
      positive_status = Observation.where(
        person_id: patient, concept_id: status_concept
      ).order(obs_datetime: :desc).first

      begin
        return positive_status\
        if (positive_status.value_coded == positive_concept) && patient_is_under_five?(patient)
      rescue StandardError
        nil
      end
    end

    def current_program (patient)
      patient.patient_programs.where(program_id: @program)\
                              .order(date_enrolled: :asc)\
                              .first
    end

    def saved_encounters(patient, date)
      Encounter.where(program_id: @program, patient_id: patient)\
               .where('DATE(encounter_datetime) = ?', date)\
               .collect(&:name).uniq
    end

    private

    def patient_summary(patient, date)
      TbService::PatientSummary.new patient, date
    end

    def patient_is_under_five?(patient)
      person = Person.find_by(person_id: patient)
      ((Time.zone.now - person.birthdate.to_time) / 1.year.seconds).floor < 5
    end

  end
end
