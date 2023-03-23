# frozen_string_literal: true

require 'swagger_helper'

TAG = 'Reports'
TAG_DESCRIPTION = 'Reports Endpoints'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'api/v1/reports', type: :request do
  path '/api/v1/defaulter_list' do
    get('defaulter_list report') do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      parameter name: :start_date, in: :query, type: :string, format: :date, example: '2022-10-1', required: true
      parameter name: :end_date, in: :query, type: :string, format: :date, example: '2022-12-1', required: true
      parameter name: :pepfar, in: :query, type: :string, example: 'moh or pepfar', required: true
      parameter name: :program_id, in: :query, type: :integer, example: 1, required: true
      security [api_key: []]
      response(200, 'successful') do
        schema type: :array, items: {
          type: :object, properties: {
            person_id: { type: :integer },
            given_name: { type: :string },
            family_name: { type: :string },
            birthdate: { type: :string },
            gender: { type: :string },
            arv_number: { type: :string },
            outcome: { type: :string },
            defaulter_date: { type: :string, format: :date, example: '2019-01-01' },
            appointment_date: { type: :string, format: :date, example: '2019-01-01' },
            art_reason: { type: :string },
            cell_number: { type: :string },
            district: { type: :string },
            ta: { type: :string },
            village: { type: :string },
            current_age: { type: :string }
          }
        }

        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
