# frozen_string_literal: true

require 'swagger_helper'

TAGS_NAME = 'Clinic Reports'

describe 'Clinic Reports API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/programs/1/reports/clinic_tx_rtt' do
    get 'Retrieve CLINIC TX RTT report' do
      tags TAGS_NAME
      description 'This shows CLINIC TX RTT report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'CLINIC TX RTT Report found' do
        schema type: :object, properties: {
          age_group: { type: :object, properties: {
            gender: { type: :array, items: {
              type: :object, properties: {
                patient_id: { type: :integer },
                months: { type: :integer }
              }
            } }
          } }
        }
        run_test!
      end

      response '404', 'CLINIC TX RTT Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/tpt_outcome' do
    get 'Retrieve TPT OUTCOME report' do
      tags TAGS_NAME
      description 'This shows TPT OUTCOME report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'TPT OUTCOME Report found' do
        schema type: :array, items: {
          type: :object, properties: {
            age_group: { type: :string },
            tpt_type: { type: :string },
            started_tpt: { type: :array, items: {
              type: :integer
            } },
            completed_tpt: { type: :array, items: {
              type: :integer
            } },
            not_completed_tpt: { type: :array, items: {
              type: :integer
            } },
            died: { type: :array, items: {
              type: :integer
            } },
            defaulted: { type: :array, items: {
              type: :integer
            } },
            transferred_out: { type: :array, items: {
              type: :integer
            } },
            confirmed_tb: { type: :array, items: {
              type: :integer
            } },
            pregnant: { type: :array, items: {
              type: :integer
            } },
            stopped: { type: :array, items: {
              type: :integer
            } },
            breast_feeding: { type: :array, items: {
              type: :integer
            } },
            skin_rash: { type: :array, items: {
              type: :integer
            } },
            peripheral_neuropathy: { type: :array, items: {
              type: :integer
            } },
            yellow_eyes: { type: :array, items: {
              type: :integer
            } },
            nausea: { type: :array, items: {
              type: :integer
            } },
            dizziness: { type: :array, items: {
              type: :integer
            } }
          }
        }
        run_test!
      end

      response '404', 'TPT OUTCOME Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/programs/1/reports/vl_collection' do
    get 'Retrieve TPT OUTCOME report' do
      tags TAGS_NAME
      description 'This shows TPT OUTCOME report'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string
      parameter name: :end_date, in: :query, type: :string

      response '200', 'VL Collection Report found' do
        schema type: :array, items: { '$ref' => '#/components/schemas/vl_collection' }
        run_test!
      end

      response '404', 'VL Collection Report not found' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
