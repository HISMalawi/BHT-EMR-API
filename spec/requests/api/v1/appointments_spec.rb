# frozen_string_literal: true

require 'swagger_helper'

TAG_NAME = 'Appointments'
TAG_DESCRIPTION = 'Appointments Endpoints'

RSpec.describe 'api/v1/appointments', type: :request do

  path '/api/v1/next_appointment' do

    get('list appointments') do
      tags TAG_NAME
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :patient_id, in: :query, type: :integer, example: 1, description: 'Patient ID', required: true, default: 1
      parameter name: :program_id, in: :query, type: :integer, example: 1, description: 'Program ID', required: true, default: 1
      parameter name: :date, in: :query, type: :string, format: 'date', example: '2020-01-01', description: 'Date in YYYY-MM-DD format', required: true

      response(200, 'successful') do
        schema type: :object, properties: {
          appointment_date: { type: :string, format: 'date' },
        }, required: %w[appointment_date]

        run_test!
      end

      response(404, 'not found') do
        let(:patient_id) { 'invalid' }
        let(:program_id) { 'invalid' }
        let(:date) { 'invalid' }

        schema type: :object, properties: {
          errors: { type: :string },
        }, required: %w[errors]

        run_test!
      end
    end
  end
end
