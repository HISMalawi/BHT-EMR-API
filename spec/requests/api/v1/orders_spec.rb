require 'swagger_helper'

TAGS_NAME = 'Orders'.freeze

describe 'Orders API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/orders/radiology' do
    post 'Adds a Radiology Order' do
      tags TAGS_NAME
      description 'This adds a radiology order to the system'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :id, in: :body, schema: {
        type: :object, properties: {
          encounter_id: { type: :integer },
          concept_id: { type: :integer },
          instructions: { type: :string },
          start_date: { type: :string },
          orderer: { type: :integer },
          accession_number: { type: :string },
          provider: { type: :integer }
        },
        required: %w[encounter_id concept_id]
      }

      response '201', 'Radiology Order Created' do
        schema type: :object, properties: {
          order_id: { type: :integer },
          accession_number: { type: :string },
          created_at: { type: :string },
          updated_at: { type: :string }
        }
        run_test!
      end

      response '422', 'Radiology Order not created' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end

      response '404', 'Encounter not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end

      response '500', 'Internal Server Error' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
