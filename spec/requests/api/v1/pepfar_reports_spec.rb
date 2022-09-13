require 'swagger_helper'

TAGS_NAME = 'Pepfar Reports'.freeze

describe 'Pepfar Reports API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/programs/12/reports/pmtct_stat_art' do
    get 'Retrieve PMTCT STAT ART' do
      tags TAGS_NAME
      description 'This shows PMTCT STAT ART report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'PMTCT STAT ART Report found' do
        schema type: :array, items: {
          type: :object, properties: {
            age_group: { type: :string },
            known_positive: { type: :array, items: { type: :integer } },
            newly_tested_positives: { type: :array, items: { type: :integer } },
            new_negatives: { type: :array, items: { type: :integer } },
            recent_negatives: { type: :array, items: { type: :integer } },
            not_done: { type: :array, items: { type: :integer } },
            new_on_art: { type: :array, items: { type: :integer } },
            already_on_art: { type: :array, items: { type: :integer } }
          }
        }
        run_test!
      end

      response '404', 'PMTCT STAT ART Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
