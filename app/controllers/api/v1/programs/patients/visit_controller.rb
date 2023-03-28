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

      # dates should only be from 2 years ago
      visit_dates = visits_dates.select { |date| date.to_date >= 2.years.ago.to_date }

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
    page_2_template = File.read(Rails.root.join('app', 'views', 'layouts', 'patient_card_page_two.html.erb'))
    patient_details[:visits] = patient[:visits].drop(8)      
    @data = patient_details
    ERB.new(page_2_template).result(binding) if patient_details[:visits].present?
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
