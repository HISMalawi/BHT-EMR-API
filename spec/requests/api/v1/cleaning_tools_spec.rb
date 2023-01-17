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
        # returns an array of objects from the component schema
        schema type: :array, items: { '$ref': '#/components/schemas/multiple_filing_numbers' }
        run_test!
      end
    end
  end
end

