# frozen_string_literal: true

require 'swagger_helper'

DATA_CLEANING_SUPERVISION_TAG = 'Data Cleaning Supervision Endpoints'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'api/v1/data_cleaning_supervisions', type: :request do
  path '/api/v1/data_cleaning_supervisions' do
    get('list data_cleaning_supervisions') do
      tags DATA_CLEANING_SUPERVISION_TAG
      description 'List data cleaning supervisions'
      produces 'application/json'
      security [api_key: []]
      parameter name: :paginate, in: :query, type: :boolean, description: 'paginate results'
      parameter name: :page, in: :query, type: :integer, description: 'page number'
      parameter name: :page_size, in: :query, type: :integer, description: 'per page count'
      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/data_cleaning_supervision' }
        run_test!
      end
    end

    post('create data_cleaning_supervision') do
      tags DATA_CLEANING_SUPERVISION_TAG
      description 'Create data cleaning supervision'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :data_cleaning_supervision, in: :body, schema: {
        type: :object,
        properties: {
          data_cleaning_datetime: { type: :string, format: 'date-time' },
          comments: { type: :string },
          supervisors: { type: :string, description: 'Supervisors separated by ;' }
        }
      }
      response(200, 'successful') do
        # returns the created data_cleaning_supervision
        schema '$ref' => '#/components/schemas/data_cleaning_supervision'
        run_test!
      end
    end
  end

  path '/api/v1/data_cleaning_supervisions/{id}' do
    # You'll want to customize the parameter types...
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show data_cleaning_supervision') do
      tags DATA_CLEANING_SUPERVISION_TAG
      description 'Show data cleaning supervision'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: []]
      response(200, 'successful') do
        let(:id) { '123' }
        schema '$ref' => '#/components/schemas/data_cleaning_supervision'
        run_test!
      end
    end

    put('update data_cleaning_supervision') do
      tags DATA_CLEANING_SUPERVISION_TAG
      description 'Update data cleaning supervision'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :data_cleaning_supervision, in: :body, schema: {
        type: :object,
        properties: {
          data_cleaning_datetime: { type: :string, format: 'date-time' },
          comments: { type: :string },
          supervisors: { type: :string, description: 'Supervisors separated by ;' }
        }
      }
      response(200, 'successful') do
        let(:id) { '123' }
        schema '$ref' => '#/components/schemas/data_cleaning_supervision'
        run_test!
      end
    end

    delete('delete data_cleaning_supervision') do
      tags DATA_CLEANING_SUPERVISION_TAG
      description 'Delete data cleaning supervision'
      produces 'application/json'
      consumes 'application/json'
      security [api_key: []]
      parameter name: :reason, in: :query, type: :string, description: 'reason for deletion'
      response(200, 'successful') do
        let(:id) { '123' }
        schema type: :object, properties: { message: { type: :string } }
        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
