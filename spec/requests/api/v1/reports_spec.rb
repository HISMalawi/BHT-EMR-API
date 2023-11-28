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
            current_age: { type: :string },
            landmark: { type: :string }
          }
        }

        run_test!
      end
    end
  end

  path '/api/v1/latest_regimen_dispensed' do
    get 'latest_regimen_dispensed report' do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      parameter name: :start_date, in: :query, type: :string, format: :date, example: '2022-10-1', required: true
      parameter name: :end_date, in: :query, type: :string, format: :date, example: '2022-12-1', required: true
      parameter name: :date, in: :query, type: :string, format: :date, example: '2022-12-1', required: true
      parameter name: :program_id, in: :query, type: :integer, example: 1, required: true
      parameter name: :rebuild_outcome, in: :query, type: :boolean, example: true, required: true
      security [api_key: []]

      response(200, 'successful') do
        schema type: :array, items: {
          type: :object, properties: {
            patient_id: { type: :array, items: {
              type: :object, properties: {
                order_id: { type: :object, properties: {
                  name: { type: :string },
                  quantity: { type: :integer },
                  dispensation_date: { type: :string, format: :date, example: '2019-01-01' },
                  identifier: { type: :string },
                  gender: { type: :string },
                  birthdate: { type: :string, format: :date, example: '2019-01-01' },
                  drug_id: { type: :integer },
                  pack_sizes: { type: :array, items: { type: :integer } },
                  vl_latest_order_date: { type: :string, format: :date, example: '2019-01-01' },
                  vl_latest_result_date: { type: :string, format: :date, example: '2019-01-01' },
                  vl_latest_result: { type: :string }
                }
                },
              }
            } }
          }
        }

        run_test!
      end

      response(500, 'failed') do
        schema type: :object, properties: {
          error: { type: :string }
        }
        run_test!
      end
    end
  end

  # http://localhost:3000/api/v1//patients/26/tpt_status?
  path '/api/v1/patients/{id}/tpt_status' do
    get 'tpt_status report' do
      tags TAG
      description TAG_DESCRIPTION
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer, example: 1, required: true
      parameter name: :current_date, in: :query, type: :string, format: :date, example: '2022-10-1', required: true
      security [api_key: []]

      response(200, 'successful') do
        # use the schema defined in the swagger_helper
        schema '$ref' => '#/components/schemas/tpt_status'
        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
