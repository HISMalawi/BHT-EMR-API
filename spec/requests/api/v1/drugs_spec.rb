require 'swagger_helper'

TAGS_NAME = 'Drugs'.freeze

describe 'Drugs API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/arv_drugs' do
    get 'Returns a list of ARV drugs' do
      tags TAGS_NAME
      description 'This returns a list of ARV drugs'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]

      response '200', 'ARV Drugs returned' do
        schema type: :array, items: {
          type: :object,
          properties: {
            drug_id: { type: :integer },
            concept_id: { type: :integer },
            name: { type: :string },
            dosage_form: { type: :integer },
            dosage_strength: { type: :float },
            maximum_daily_dose: { type: :float },
            minimum_daily_dose: { type: :float },
            route: { type: :integer },
            units: { type: :string },
            creator: { type: :integer },
            date_created: { type: :string },
            retired: { type: :boolean },
            retired_by: { type: :integer },
            date_retired: { type: :string },
            retire_reason: { type: :string },
            uuid: { type: :string },
            alternative_names: { type: :array, items: { type: :object, properties: {
              id: { type: :integer },
              name: { type: :string },
              short_name: { type: :string },
              created_at: { type: :string },
              updated_at: { type: :string }
            } } },
            barcodes: { type: :array, items: { type: :object, properties: {
              drug_order_barcode_id: { type: :integer },
              drug_id: { type: :integer },
              tabs: { type: :integer },
              created_at: { type: :string },
              updated_at: { type: :string }
            } } }
          }
        }
        run_test!
      end
    end
  end
end
