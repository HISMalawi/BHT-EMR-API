require 'swagger_helper'

TAGS_NAME = 'Internal Sections'.freeze

describe 'Internal Sections API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/internal_sections' do
    get 'Retrieve all internal sections' do
      tags TAGS_NAME
      description 'This shows all internal sections'
      produces 'application/json'
      security [api_key: []]

      response '200', 'Internal Sections found' do
        schema type: :array, items: {
          type: :object, properties: {
            id: { type: :integer },
            name: { type: :string },
            created_at: { type: :string },
            updated_at: { type: :string }
          }
        }
        run_test!
      end

      response '404', 'Internal Sections not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/internal_sections/{id}' do
    get 'Retrieve internal section by id' do
      tags TAGS_NAME
      description 'This shows internal section by id'
      produces 'application/json'
      security [api_key: []]
      parameter name: :id, in: :path, type: :integer

      response '200', 'Internal Section found' do
        schema type: :object, properties: {
          id: { type: :integer },
          name: { type: :string },
          created_at: { type: :string },
          updated_at: { type: :string }
        }
        run_test!
      end

      response '404', 'Internal Section not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/internal_sections/' do
    post 'Create internal section' do
      tags TAGS_NAME
      consumes 'application/json'
      security [api_key: []]
      parameter name: :params, in: :body, schema: {
        type: :object, properties: {
          name: { type: :string }
        },
        required: %w[name]
      }
      produces 'application/json'

      response '201', 'Internal Section created' do
        schema type: :object, properties: {
          id: { type: :integer },
          name: { type: :string },
          created_at: { type: :string },
          updated_at: { type: :string }
        }
        run_test!
      end

      response '422', 'Internal Section not created' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end

    path '/api/v1/internal_sections/{id}' do
      put 'Update internal section' do
        tags TAGS_NAME
        consumes 'application/json'
        security [api_key: []]
        parameter name: :id, in: :path, type: :integer
        parameter name: :params, in: :body, schema: {
          type: :object, properties: {
            name: { type: :string }
          },
          required: %w[name]
        }
        produces 'application/json'

        response '200', 'Internal Section updated' do
          schema type: :object, properties: {
            id: { type: :integer },
            name: { type: :string },
            created_at: { type: :string },
            updated_at: { type: :string }
          }
          run_test!
        end

        response '422', 'Internal Section not updated' do
          schema type: :string, properties: {
            message: { type: :string }
          }
          run_test!
        end
      end
    end

    path '/api/v1/internal_sections/{id}' do
      delete 'Remove internal section' do
        tags TAGS_NAME
        consumes 'application/json'
        security [api_key: []]
        parameter name: :id, in: :path, type: :integer
        parameter name: :void_reason, in: :body, schema: {
          type: :object, properties: {
            void_reason: { type: :string }
          },
          required: %w[void_reason]
        }
        produces 'application/json'

        response '200', 'Internal Section removed' do
          schema type: :string, properties: {
            message: { type: :string }
          }
          run_test!
        end

        response '422', 'Internal Section not removed' do
          schema type: :string, properties: {
            message: { type: :string }
          }
          run_test!
        end
      end
    end
  end
end
