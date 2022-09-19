require 'swagger_helper'

TAGS_NAME = 'Pharmacy'.freeze

describe 'Pharmacy API', type: :request, swagger_doc: 'v1/swagger.yaml' do
  path '/api/v1/pharmacy/stock_report' do
    get 'Stock Report' do
      tags TAGS_NAME
      description 'This gets the stock report'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]

      response '200', 'Stock Report' do
        schema type: :array, items: {
          type: :object, properties: {
            product_code: { type: :string },
            batch_numbers: { type: :string },
            drug_name: { type: :string },
            units: { type: :string },
            closing_balance: { type: :float },
            losses: { type: :float },
            positive_adjustment: { type: :float },
            negative_adjustment: { type: :float },
            quantity_used: { type: :float },
            quantity_received: { type: :float }
          }
        }
        run_test!
      end

      response '500', 'Internal Server Error' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/pharmacy/audit_trail' do
    get 'Audit Trail' do
      tags TAGS_NAME
      description 'This gets the audit trail'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :start_date, in: :query, type: :string, required: false
      parameter name: :end_date, in: :query, type: :string, required: false
      parameter name: :drug_id, in: :query, type: :integer, required: false
      parameter name: :batch_number, in: :query, type: :string, required: false

      response '200', 'Audit Trail' do
        schema type: :array, items: {
          type: :object, properties: {
            creation_date: { type: :string },
            transaction_date: { type: :string },
            transaction_type: { type: :string },
            batch_number: { type: :string },
            drug_id: { type: :integer },
            batch_item_id: { type: :integer },
            drug_name: { type: :string },
            amount_committed_to_stock: { type: :float },
            amount_dispensed_from_art: { type: :float },
            username: { type: :string },
            transaction_reason: { type: :string },
            product_code: { type: :string }
          }
        }
        run_test!
      end

      response '500', 'Internal Server Error' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end

  path '/api/v1/pharmacy/batches' do
    post 'Add a batch' do
      tags TAGS_NAME
      description 'This adds a batch item and can create a batch if does not exist'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      parameter name: :_json, in: :body, schema: {
        type: :array, items: {
          type: :object, properties: {
            batch_number: { type: :string },
            location_id: { type: :integer },
            items: { type: :array, items: {
              type: :object, properties: {
                pack_size: { type: :integer },
                barcode: { type: :string },
                drug_id: { type: :integer },
                expiry_date: { type: :string },
                quantity: { type: :integer },
                delivery_date: { type: :string },
                product_code: { type: :string }
              }
            } }
          }
        }
      }, required: true

      response '201', 'Batch created' do
        schema type: :array, items: {
          type: :object, properties: {
            id: { type: :integer },
            batch_number: { type: :string },
            creator: { type: :integer },
            date_created: { type: :string },
            date_changed: { type: :string },
            voided: { type: :boolean },
            voided_by: { type: :integer },
            date_voided: { type: :string },
            void_reason: { type: :string },
            changed_by: { type: :integer },
            location_id: { type: :integer },
            items: { type: :array, items: {
              type: :object, properties: {
                id: { type: :integer },
                pharmacy_batch_id: { type: :integer },
                drug_id: { type: :integer },
                delivered_quantity: { type: :float },
                current_quantity: { type: :float },
                creator: { type: :integer },
                date_created: { type: :string },
                date_changed: { type: :string },
                voided: { type: :boolean },
                voided_by: { type: :integer },
                date_voided: { type: :string },
                void_reason: { type: :string },
                changed_by: { type: :integer },
                pack_size: { type: :integer },
                barcode: { type: :string },
                expiry_date: { type: :string },
                product_code: { type: :string }
              }
            } }
          }
        }
        run_test!
      end

      response '500', 'Internal Server Error' do
        schema type: :string, properties: {
          message: { type: :string }
        }
        run_test!
      end
    end
  end
end
