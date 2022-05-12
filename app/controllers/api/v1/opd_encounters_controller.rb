# frozen_string_literal: true

class Api::V1::OpdEncountersController < ApplicationController
  def fetch_encounter
    limit = params[:limit] ||= 10
    offset = params[:page] ||= 1

    render json: { data: Encounter.where(program_id: nil).limit(limit.to_i).offset((offset.to_i - 1) * limit.to_i), total: Encounter.where(program_id: nil).count },
           status: :ok
  end

  def update_encounter_program
    encounter = Encounter.find_by(encounter_id: params[:encounter_id], program_id: nil)
    raise NotFoundError, 'Encounter not found' if encounter.blank?

    encounter.update(program_id: params[:program_id])
    encounter.reload
    render json: { data: encounter, message: 'updated successfully' }, status: :ok
  end
end
