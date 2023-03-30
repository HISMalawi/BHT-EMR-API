# frozen_string_literal: true

class Api::V1::Programs::Patients::VisitController < ApplicationController
  require "./app/services/art_service/reports/master_card/mastercard_struct.rb"

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
    card_type = params[:card_type]
    htmls = patients.collect do |patient|
      mastercard_service = patient_mastercard_service(patient, card_type)

      patient_details = mastercard_service.fetch

      visits_dates = patient_service.find_patient_visit_dates(patient, program, true)

      visits_dates = visits_dates.sort! { |a, b| b.to_date <=> a.to_date }.reverse

      filtred_dates = [visits_dates[0]]
      filtred_dates += visits_dates.last(5)

      
      patient_details[:visits] = filtred_dates.collect do |date|
        { date: date }.merge(visit_summary(patient.id, date).as_json)
      end

      arvs_given = patient_details[:visits].map { |visit| {date: visit[:date], arv: visit[:arvs][0].to_a[0]} }.flatten.uniq { |visit| visit[:arv]}
      patient_details[:arvs_given] = arvs_given

      @data = patient_details
      template = patient_card card_type
      html = ERB.new(template).result(binding)

      html
    end
    render json: htmls.join("")
  end

  private

  def patient_card(card_type)
    File.read(Rails.root.join("app", "views", "layouts", "#{card_type == "child" ? "ped_patient_card" : "patient_card"}.html.erb"))
  end

  def patient_mastercard_service(patient, card_type)
    ARTService::Reports::MasterCard::PatientStruct.new(patient)
  end

  def service
    ProgramServiceLoader
      .load(Program.find(params[:program_id]), "PatientsEngine")
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
