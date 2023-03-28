# frozen_string_literal: true

class Api::V1::Programs::Patients::VisitController < ApplicationController

  require './app/services/art_service/reports/master_card/mastercard_struct.rb'

  def index
    permitted = params.permit(:date)
    date = permitted[:date]&.to_date || Date.today

    summary = service.patient_visit_summary(params[:program_patient_id], date)

    render json: summary
  end

  def visit_summary(patient_id, date)
    summary = service.patient_visit_summary(patient_id, date)

    return summary
  end

  def patient_visits
    patients = params[:patient_ids].collect { |id| patient(id) }    
    BatchPrintingJob.perform_later(patients)
    render json: { status: 'OK', message: "Your request is being processed" }
  end

  private

  def patient_mastercard_service patient
    ARTService::Reports::MasterCard::PatientStruct.new(patient)
  end
  
  def ped_patient_mastercard_service patient
    ARTService::Reports::MasterCard::PediatricCardStruct.new(patient)
  end
  
  def service
    ProgramServiceLoader
      .load(Program.find(params[:program_id]), 'PatientsEngine')
      .new
  end

  def patient_service
   PatientService.new
  end

  def patient(patient_id)
    Patient.find(patient_id)
  end

  def program 
    Program.find(params[:program_id])
  end
end
