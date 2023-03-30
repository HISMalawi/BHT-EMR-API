class BatchPrintingJob < ActiveJob::Base
  queue_as :default

  def perform(patients)
    processed = 0
    program = Program.find(1)
    patient_visit_service = service(program)
    patients.each_slice(2) do |patients_data|
      htmls = patients_data.collect do |patient|
        mastercard_service = patient_mastercard_service(patient)
        is_peds = mastercard_service.patient_is_a_pediatric?
        mastercard_service = is_peds ? ped_patient_mastercard_service(patient) : mastercard_service

        patient_details = mastercard_service.fetch

        visits_dates = patient_service.find_patient_visit_dates(patient, program, true)

        visits_dates = visits_dates.sort! { |a, b| b.to_date <=> a.to_date }.reverse

        filtred_dates = [visits_dates[0]]
        filtred_dates += visits_dates.last(5)

        patient_details[:visits] = filtred_dates.collect do |date|
          { date: date }.merge(patient_visit_service.patient_visit_summary(patient.id, date).as_json)
        end

        @data = patient_details
        template = File.read(Rails.root.join("app", "views", "layouts", is_peds ? "ped_patient_card.html.erb" : "patient_card.html.erb"))
        html = ERB.new(template).result(binding)

        processed += 1
          { html: html }
      end
      ActionCable.server.broadcast "printing_channel", { processed: processed, total: patients.length, data: htmls }
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

  def service(program)
    ProgramServiceLoader
      .load(program, "PatientsEngine")
      .new
  end
end
