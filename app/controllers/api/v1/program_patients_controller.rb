class Api::V1::ProgramPatientsController < ApplicationController
  def show
    date = params[:date]&.to_date || Date.today
    render json: service.patient(params[:id], date)
  end

  def last_drugs_received
    render json: service.patient_last_drugs_received(patient)
  end

  def find_dosages
    service = RegimenService.new(program_id: params[:program_id])
    dosage = service.find_dosages patient, (params[:date]&.to_date || Date.today)
    render json: dosage
  end

  def status
    status = service.find_status patient, (params[:date]&.to_date || Date.today)
    render json: status
  end

  def find_earliest_start_date
    date_enrolled = service.find_patient_date_enrolled(patient)
    earliest_start_date = service.find_patient_earliest_start_date(patient, date_enrolled)

    render json: {
      date_enrolled: date_enrolled,
      earliest_start_date: earliest_start_date
    }
  end

  protected

  def service
    @service ||= ProgramPatientsService.new program: program
  end

  def program
    @program ||= Program.find(params[:program_id])
  end

  def patient
    @patient ||= Patient.find(params[:program_patient_id])
  end
end
