require 'swagger_helper'

TAGS_NAME = 'Concept Sets'.freeze

describe 'Concept Sets API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/radiology_set' do
    get 'Retrieve all radiology sets' do
      tags TAGS_NAME
      description 'This shows all radiology examination sets'
      produces 'application/json'
      security [api_key: []]
      parameter name: :id, in: :query, type: :string

      response '200', 'Radiology Sets found' do
        schema type: :array, items: {
          type: :object, properties: {
            concept_id: { type: :integer },
            name: { type: :string }
          }
        }
        run_test!
      end
    end
  end

  path '/api/v1/concept_sets/{id}' do
    get 'Retrieve concept set by id' do
      tags TAGS_NAME
      description 'This shows concept set by id'
      produces 'application/json'
      security [api_key: []]
      parameter name: :id, in: :path, type: :integer

      response '200', 'Concept Set found' do
        schema type: :object, properties: {
          id: { type: :integer },
          name: { type: :string },
          created_at: { type: :string },
          updated_at: { type: :string }
        }
        run_test!
      end

      response '404', 'Concept Set not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
