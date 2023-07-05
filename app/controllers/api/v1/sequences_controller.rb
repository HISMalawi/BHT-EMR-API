# frozen_string_literal: true

module Api
  module V1
    class SequencesController < ApplicationController
      def next_accession_number
        render json: { accession_number: SequencesService.next_accession_number }
      end
    end
  end
end
