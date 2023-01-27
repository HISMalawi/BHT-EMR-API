# frozen_string_literal: true

require 'swagger_helper'

TAGS_NAME = 'Cleaning Tools'

describe 'Cleaning Tools API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/art_data_cleaning_tools' do
    get 'Retrieve patients with data problems' do
      tags TAGS_NAME
      description 'This shows the patients with data problems'
      produces 'application/json'
      security [api_key: []]
      # parameter get from component schema
      parameter name: :params, in: :query, schema: { '$ref': '#/components/schemas/data_cleaning_request' }

      response '200', 'You can cross check the different responses in the swagger documentation' do
        # returns an array of objects from the component schema using oneOf
        schema type: :array, items: { '$ref': '#/components/schemas/multiple_identifiers' }
        run_test!
      end
    end
  end

  path '/api/v1/void_multiple_identifiers' do
    delete 'Void multiple filing numbers' do
      tags TAGS_NAME
      description 'This voids multiple filing numbers'
      consumes 'application/json'
      security [api_key: []]
      # request body
      parameter name: :params, in: :body, schema: { '$ref': '#/components/schemas/void_multiple_identifiers' }

      response '204', 'Returns no content' do
        let(:params) { { identifiers: [{ identifier: 'FN10100001', patient_id: 347 }], reason: 'Testing voiding' } }
        run_test!
      end
    end
  end
end
