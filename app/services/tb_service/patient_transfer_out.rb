# frozen_string_literal: true

  # Provides various data that is required for a transfer out note
  class TbService::PatientTransferOut
    include ModelUtils

    attr_accessor :patient, :date

    def initialize(patient, date)
      @patient = patient
      @program = program('TB Program')
      @date = date
    end

    def enrollment_date
      patients_engine.current_program(@patient)&.date_enrolled
    end

    def transfer_out_date
      @date
    end

    def current_regimen
      drugs = patients_engine.patient_last_drugs_received(@patient, @date)
      drugs_str(drugs)
    end

    def drugs_dispensed
      drugs = patients_engine.drugs_dispensed_on_date(@patient, @date)
      drugs_str(drugs)
    end

    def transferred_out_to
      'N/A'
    end

    private

    def patients_engine
      TbService::PatientsEngine.new(program: @program)
    end

    def transfer_out_location
    end

    def drugs_str (drugs)
      !drugs.empty? ? (drugs.map { |order| order.drug.name } ).join(',') : 'N/A'
    end
  end
