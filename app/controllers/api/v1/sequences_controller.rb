# frozen_string_literal: true

class Api::V1::SequencesController < ApplicationController
  def next_accession_number
    render json: { accession_number: SequencesService.next_accession_number }
  end
end
