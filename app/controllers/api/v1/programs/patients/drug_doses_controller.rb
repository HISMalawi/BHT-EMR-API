# frozen_string_literal: true

##
# Find the right dosages for a given drug for a patient in a given program.
class Api::V1::Programs::Patients::DrugDosesController < ApplicationController
  def index
    service = ProgramEngineLoader.load(program, 'DosagesEngine')
    drug_id = params.require(:drug_id)
    date = params[:date]&.to_date || Date.today

    dosage = service.find_drug_dose(drug_id, params[:program_patient_id], date)

    if dosage
      render json: dosage, status: :ok
    else
      render json: { errors: ["Dosage for drug ##{drug_id} not found"] }, status: :not_found
    end
  end

  private

  def program
    Program.find(params[:program_id])
  end
end
