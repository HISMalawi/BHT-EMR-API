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
    htmls = patients.collect do | patient |

      mastercard_service = patient_mastercard_service(patient)
      mastercard_service = mastercard_service.patient_is_a_pediatric? ? ped_patient_mastercard_service(patient) : mastercard_service

      patient_details = mastercard_service.fetch

      visits_dates = patient_service.find_patient_visit_dates(patient, program, params[:include_defaulter_dates] == 'true')      

      patient_details[:visits] = visits_dates.reverse.collect do | date |
        {date: date}.merge(visit_summary(patient.id, date).as_json)
      end

      @data = patient_details
      template = File.read(Rails.root.join('app', 'views', 'layouts', 'patient_card.html.erb'))
      html = ERB.new(template).result(binding)

      page_two_data = load_page_data(@data)
      
      {html: html+page_two_data}
    end
    render json: htmls
  end
  
  def load_page_data(patient_details)
    html_string = ""
    page_2_template = File.read(Rails.root.join('app', 'views', 'layouts', 'patient_card_page_two.html.erb'))
    patient_details[:visits].each_slice(8).to_a.each_with_index do |slice, index|
      patient = patient_details 
      patient[:visits] = patient[:visits].drop(8)      
      @data = patient
      html_string += ERB.new(page_2_template).result(binding) if patient[:visits].present?
    end
    html_string
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
