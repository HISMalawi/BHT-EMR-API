# frozen_string_literal: true

require 'swagger_helper'

TAGS_NAME = 'Data Management Tools'

describe 'Data Management Tools API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/search/identifiers/multiples' do
    get 'Retrieve patients with data problems' do
      tags TAGS_NAME
      description 'This shows the patients with data problems'
      produces 'application/json'
      security [api_key: []]
      # parameter is just a type id
      parameter name: :type_id, in: :query, schema: { type: :integer }

      response '200', 'You can cross check the different responses in the swagger documentation' do
        # returns an array of objects from the component schema using oneOf
        schema type: :array, items: { '$ref': '#/components/schemas/multiple_identifiers' }
        run_test!
      end
    end
  end
end