# frozen_string_literal: true

require 'swagger_helper'
TAG = 'Observation Controller'

RSpec.describe 'Observation API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  let(:encounter) { create(:encounter) }
  let(:obs_params) do
    {
      concept_id: create(:concept).concept_id,
      obs_datetime: Time.now,
      value_text: 'Foobar',
      child: [
        {
          concept_id: create(:concept).concept_id,
          obs_datetime: Time.now,
          value_coded: create(:concept).concept_id
        },
        {
          concept_id: create(:concept).concept_id,
          obs_datetime: Time.now,
          value_coded: create(:concept).concept_id
        }
      ]
    }
  end

  path '/api/v1/observations' do
    post 'Create new observation' do
      tags TAG
      consumes 'application/json'
      security [api_key: []]
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          encounter_id: { type: :integer },
          observations: { type: :object, properties: {
            concept_id: { type: :integer },
            obs_datetime: { type: :string },
            value_coded: { type: :integer },
            value_text: { type: :string },
            value_numeric: { type: :number },
            value_datetime: { type: :string },
            value_drug: { type: :integer },
            value_boolean: { type: :boolean },
            child: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  concept_id: { type: :integer },
                  obs_datetime: { type: :string },
                  value_coded: { type: :integer },
                  value_text: { type: :string },
                  value_numeric: { type: :number },
                  value_datetime: { type: :string },
                  value_drug: { type: :integer },
                  value_boolean: { type: :boolean }
                }
              }
            }
          } }

        },
        required: %w[concept_id]
      }
      produces 'application/json'

      response '201', 'Observation created' do
        let(:encounter_id) { encounter.encounter_id }
        let(:observations) { obs_params }
        xit
      end
    end
  end
end
