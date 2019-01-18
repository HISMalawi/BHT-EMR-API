require 'zebra_printer/init'

class Api::V1::ProgramPatientsController < ApplicationController
  before_action :authenticate, except: %i[print_visit_label print_transfer_out_label]

  def show
    date = params[:date]&.to_date || Date.today
    render json: service.patient(params[:id], date)
  end

  def last_drugs_received
    date = params[:date]&.to_date || Date.today
    render json: service.patient_last_drugs_received(patient, date)
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

  def find_next_available_arv_number
    render json: { arv_number: service.find_next_available_arv_number }
  end

  def lookup_arv_number
    if (service.arv_number_already_exists(params[:arv_number]))
      render json: { exists: true }
    else
      render json: { exists: false }
    end
  end

  def print_visit_label
    label_commands = service.visit_summary_label(patient, date).print
    send_data label_commands, type: 'application/label; charset=utf-8',
                              stream: false,
                              filename: "#{params[:patient_id]}#{rand(10_000)}.lbl",
                              disposition: 'inline'
  end

  def print_transfer_out_label
    label_commands = service.transfer_out_label(patient, date).print
    send_data label_commands, type: 'application/label; charset=utf-8',
                              stream: false,
                              filename: "#{params[:patient_id]}#{rand(10_000)}.lbl",
                              disposition: 'inline'
  end

  def defaulter_list
    start_date  = params[:start_date].to_date
    end_date    = params[:end_date].to_date
    defaulters  = service.defaulter_list start_date, end_date

    render json: defaulters
  end

  def mastercard_data
    render json: service.mastercard_data(patient, date)
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

  def date
    @date ||= params[:date]&.to_time || Time.now
  end
end
