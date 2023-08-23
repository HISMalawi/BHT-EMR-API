# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'EMR API V1 DOCS',
        version: 'v1'
      },
      paths: {},
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: 'Authorization',
            in: :header
          }
        },
        schemas: {
          stock_card: {
            type: :object,
            properties: {
              drug_id: { type: :integer },
              drug_name: { type: :string },
              opening_balance: { type: :number },
              closing_balance: { type: :number },
              dispensed_quantity: { type: :number },
              pack_size: { type: :integer }
            }
          },
          notification_alert: {
            type: :object,
            properties: {
              alert_id: { type: :integer },
              text: { type: :string },
              satisfied_by_any: { type: :boolean },
              alert_read: { type: :boolean },
              date_to_expire: { type: :string, format: 'date-time' },
              creator: { type: :integer },
              date_created: { type: :string, format: 'date-time' },
              changed_by: { type: :integer },
              date_changed: { type: :string, format: 'date-time' },
              uuid: { type: :string }
            }
          },
          lims_electronic_result: {
            type: :object,
            properties: {
              date_ordered: { type: :string, format: 'date-time' },
              given_name: { type: :string },
              family_name: { type: :string },
              arv_number: { type: :string },
              patient_id: { type: :integer },
              date_received: { type: :string, format: 'date-time' },
              accession_number: { type: :string },
              result: { type: :string },
              test_name: { type: :string },
              result_delivery_mode: { type: :string },
              status: { type: :string }
            }
          },
          vl_collection: {
            type: :object,
            properties: {
              patient_id: { type: :integer },
              given_name: { type: :string },
              family_name: { type: :string },
              gender: { type: :string },
              birthdate: { type: :string },
              identifier: { type: :string },
              order_date: { type: :string, format: :date }
            }
          },
          gender: { type: :string, enum: %w[M F Unknown] },
          age_group: { type: :string, enum: ['Unknown', '<1 year', '1-4 years', '5-9 years',
                                             '10-14 years', '15-19 years', '20-24 years', '25-29 years', '30-34 years',
                                             '35-39 years', '40-44 years', '45-49 years', '50-54 years', '55-59 years', '60-64 years',
                                             '65-69 years', '70-74 years', '75-79 years', '80-84 years', '85-89 years', '90 plus years'] },
          hts_hiv_results: {
            type: :object,
            properties: {
              neg: { type: :array, items: { type: :integer } },
              pos: { type: :array, items: { type: :integer } }
            }
          },
          hts_recency_results: {
            type: :object,
            properties: {
              recent: { type: :array, items: { type: :integer } },
              long_term: { type: :array, items: { type: :integer } }
            }
          },
          hts_index_common: {
            type: :object,
            properties: {
              new_positives: { type: :array, items: { type: :integer } },
              new_negatives: { type: :array, items: { type: :integer } },
              known_positives: { type: :array, items: { type: :integer } },
              documented_negatives: { type: :array, items: { type: :integer } }
            }
          },
          hts_tst_community: {
            type: :object,
            properties: {
              gender: { '$ref' => '#/components/schemas/gender' },
              age_group: { '$ref' => '#/components/schemas/age_group' },
              index_comm: { '$ref' => '#/components/schemas/hts_hiv_results' },
              mobile_comm: { '$ref' => '#/components/schemas/hts_hiv_results' },
              sns_comm: { '$ref' => '#/components/schemas/hts_hiv_results' },
              vct_comm: { '$ref' => '#/components/schemas/hts_hiv_results' },
              other_comm_tp: { '$ref' => '#/components/schemas/hts_hiv_results' }
            }
          },
          hts_index: {
            type: :object,
            properties: {
              gender: { '$ref' => '#/components/schemas/gender' },
              age_group: { '$ref' => '#/components/schemas/age_group' },
              index_clients: { type: :array, items: { type: :integer } },
              offered_clients: { type: :array, items: { type: :integer } },
              contacted_elicited: { type: :array, items: { type: :object, properties: {
                patient: { type: :integer },
                contacts: { type: :integer }
              } } },
              facility: { '$ref' => '#/components/schemas/hts_index_common' },
              community: { '$ref' => '#/components/schemas/hts_index_common' }
            }
          },
          hts_recent_community: {
            type: :object,
            properties: {
              gender: { '$ref' => '#/components/schemas/gender' },
              age_group: { '$ref' => '#/components/schemas/age_group' },
              index: { '$ref' => '#/components/schemas/hts_recency_results' },
              mobile_comm: { '$ref' => '#/components/schemas/hts_recency_results' },
              sns_comm: { '$ref' => '#/components/schemas/hts_recency_results' },
              vct_comm: { '$ref' => '#/components/schemas/hts_recency_results' },
              other_comm_tp: { '$ref' => '#/components/schemas/hts_recency_results' }
            }
          },
          discrepancy_report: {
            type: :array, items: {
              type: :object, properties: {
                drug_id: { type: :integer },
                name: { type: :string },
                short_name: { type: :string },
                verification_date: { type: :string, format: 'date-time' },
                verification_reason: { type: :string },
                difference: { type: :integer },
                current_quantity: { type: :integer },
                variance_reason: { type: :string }
              }
            }
          }
        }
      },
      security: [api_key: []],
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end
