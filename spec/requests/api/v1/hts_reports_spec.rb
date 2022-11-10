# frozen_string_literal: true

require 'swagger_helper'
TAG = 'HTS Reports'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'HTS Reports', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/hts_reports' do
    get 'Returns HTS Reports' do
      tags TAG
      description 'This returns a report based on the name of the report. For specific response structure, do checkout the schema sections'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string
      parameter name: :name, in: :query, type: :string

      response('200', 'Example for HTS INDEX') do
        schema type: :array, items: { '$ref' => '#/components/schemas/hts_index' }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS INDEX' }

        run_test!
      end

      response('200', 'Example for HTS RECENT COMMUNITY') do
        schema type: :array, items: { '$ref' => '#/components/schemas/hts_recent_community' }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS RECENT COMMUNITY' }

        run_test!
      end

      response('404', "Example if the report doesn't exists") do
        schema type: :object, properties: { errors: { type: :string } }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS I' }

        run_test!
      end

      response('400', 'Example start date is greater than end date') do
        schema type: :object, properties: { errors: { type: :string } }
        let(:start_date) { '2019-12-31' }
        let(:end_date) { '2019-01-01' }
        let(:name) { 'HTS INDEX' }

        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
