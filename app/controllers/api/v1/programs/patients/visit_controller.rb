# frozen_string_literal: true

class Api::V1::Programs::Patients::VisitController < ApplicationController
   
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
    visits = patient_service.find_patient_visit_dates(patient, program,
      params[:include_defaulter_dates] == 'true')
     all_visits = {}    
    visits.each do | visit |
      all_visits[visit] = visit_summary(patient.id, visit)
    end

    render json: all_visits
  end

  private
  
  def service
    ProgramServiceLoader
      .load(Program.find(params[:program_id]), 'PatientsEngine')
      .new
  end

  def patient_service
   PatientService.new
  end

  def patient
    Patient.find(params[:id] || params[:program_patient_id])
  end

  def program 
    Program.find(params[:program_id])
  end
end
