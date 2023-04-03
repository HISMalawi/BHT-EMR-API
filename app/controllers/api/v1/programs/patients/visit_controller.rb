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
    patient_ids = params[:patient_ids]
    all_patient_visits = []
    
    patient_detail = ARTService::Reports::MasterCard::PatientStruct.new

    all_patient_visits = Parallel.map(patient_ids) do |patient_id|
      patient_details = patient_detail.fetch(patient(patient_id))
      
      person = patient(patient_id)
      visits = patient_service.find_patient_visit_dates(person, program, params[:include_defaulter_dates] == 'false')
      
      all_visits = []    
      visits.each do |visit|
        all_visits << {date: visit}.merge(visit_summary(person.id, visit).as_json)
      end
      
      patient_details[:visits] = all_visits
      @data = patient_details
      
      template = File.read(Rails.root.join('app', 'views', 'layouts', 'patient_card.html.erb'))
      html = ERB.new(template).result(binding)
      
      { html: html }
    end
    
    render json: all_patient_visits
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

  def patient(patient_id)
    Patient.find(patient_id)
  end

  def program 
    Program.find(params[:program_id])
  end
end
