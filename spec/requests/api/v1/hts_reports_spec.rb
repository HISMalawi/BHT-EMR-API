# frozen_string_literal: true

require 'swagger_helper'
TAG = 'HTS Reports'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'HTS Reports', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/programs/18/reports/hts_index' do
    get 'Returns HTS Index Reports' do
      tags TAG
      description 'This returns a list of HTS Index aggregations'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string
      parameter name: :name, in: :query, type: :string

      response('200', 'HTS Index Reports returned') do
        schema type: :array, items: { '$ref' => '#/components/schemas/hts_index' }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS INDEX' }

        run_test!
      end
    end
  end

  path '/api/v1/programs/18/reports/hts_tst_community' do
    get 'Returns HTS TST Community Report' do
      tags TAG
      description 'This returns a list of HTS TST Community aggregations'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string
      parameter name: :name, in: :query, type: :string

      response('200', 'HTS TST Community Report returned') do
        schema type: :array, items: { '$ref' => '#/components/schemas/hts_tst_community' }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS TST COMMUNITY' }

        run_test!
      end
    end
  end

  path '/api/v1/programs/18/reports/hts_recent_community' do
    get 'Returns HTS Recent Community Report' do
      tags TAG
      description 'This returns a list of HTS Recent Community Report aggregations'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string
      parameter name: :name, in: :query, type: :string

      response('200', 'HTS Recent Community Report returned') do
        schema type: :array, items: { '$ref' => '#/components/schemas/hts_recent_community' }
        let(:start_date) { '2019-01-01' }
        let(:end_date) { '2019-12-31' }
        let(:name) { 'HTS RECENT COMMUNITY' }

        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
