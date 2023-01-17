require 'swagger_helper'

TAGS_NAME = 'Merge Rollback'.freeze

describe 'Rollback API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/rollback/merge_history' do
    get 'Retrieve merge history' do
      tags TAGS_NAME
      description 'This shows the timeline of client merges'
      produces 'application/json'
      security [api_key: []]
      parameter name: :identifier, in: :query, type: :string

      response '200', 'Merge History found' do
        schema type: :array, items: {
          type: :object, properties: {
            id: { type: :integer },
            primary_id: { type: :integer },
            secondary_id: { type: :integer },
            merge_date: { type: :string },
            merge_type: { type: :string },
            primary_first_name: { type: :string },
            primary_surname: { type: :string },
            primary_gender: { type: :string },
            primary_birthdate: { type: :string },
            secondary_first_name: { type: :string },
            secondary_surname: { type: :string },
            secondary_gender: { type: :string },
            secondary_birthdate: { type: :string }
          }
        }
        xit
      end

      response '404', 'Merge History not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        let(:identifier) { 'invalid' }
        run_test!
      end
    end
  end

  path '/api/v1/rollback/rollback_patient' do
    post 'Rollback patient merge' do
      tags TAGS_NAME
      consumes 'application/json'
      security [api_key: []]
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          patient_id: { type: :integer },
          program_id: { type: :integer }
        },
        required: %w[patient_id program_id]
      }
      produces 'application/json'

      response '200', 'Patient Rolled back' do
        schema type: :object, properties: {
          patient_id: { type: :integer }
        }
        xit
      end

      response '404', 'There is no merge history of the patient' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        let(:params) { 'invalid' }
        run_test!
      end
    end
  end
end
