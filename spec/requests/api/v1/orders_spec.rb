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
        type: :object,
        properties: {
          encounter_id: { type: :integer },
          concept_id: { type: :integer },
          instructions: { type: :string, nullable: true },
          start_date: { type: :string, nullable: true },
          orderer: { type: :integer, nullable: true },
          accession_number: { type: :string, nullable: true },
          provider: { type: :integer, nullable: true }
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

    get 'Print the examination number' do
      tags TAGS_NAME
      description 'This prints a radiology examination number'
      consumes 'application/json'
      produces 'application/label'
      security [api_key: []]
      parameter name: :params, in: :query, schema: {
        type: :object,
        properties: {
          accession_number: { type: :string },
          order_id: { type: :integer }
        }
      }
      response '200', 'File printed successfully' do
        schema type: :file, properties: {
          filename: { type: :string }
        }
        run_test!
      end
      response '404', 'Examination not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
