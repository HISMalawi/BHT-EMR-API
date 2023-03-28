class BatchPrintingJob < ActiveJob::Base
  queue_as :default

  def perform(patients)
    program = Program.find(1)
    patient_history_service = service(program)
    patients.each_slice(10) do |patients_data|
      htmls = patients_data.collect do |patient|
        mastercard_service = patient_mastercard_service(patient)
        mastercard_service = mastercard_service.patient_is_a_pediatric? ? ped_patient_mastercard_service(patient) : mastercard_service

        patient_details = mastercard_service.fetch

        visits_dates = patient_service.find_patient_visit_dates(patient, program, true)

        patient_details[:visits] = visits_dates.collect do |date|
          { date: date }.merge(patient_history_service.patient_visit_summary(patient.id, date).as_json)
        end

        @data = patient_details
        template = File.read(Rails.root.join("app", "views", "layouts", "patient_card.html.erb"))

        html = ERB.new(template).result(binding)

      end
      BatchPrintingChannel.broadcast_to('batch_printing', htmls)
    end
  end

  def patient_mastercard_service(patient)
    ARTService::Reports::MasterCard::PatientStruct.new(patient)
  end

  def ped_patient_mastercard_service(patient)
    ARTService::Reports::MasterCard::PediatricCardStruct.new(patient)
  end

  def patient_service
    PatientService.new
  end

  def service program
    ProgramServiceLoader
      .load(program, 'PatientsEngine')
      .new
  end
end
