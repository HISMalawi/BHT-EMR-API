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
          data_cleaning_request: {
            type: :object,
            properties: {
              program_id: { type: :integer },
              start_date: { type: :string },
              end_date: { type: :string },
              report_name: { type: :string }
            },
            required: %w[program_id start_date end_date report_name]
          },
          multiple_identifiers: {
            type: :object,
            properties: {
              patient_id: { type: :integer },
              given_name: { type: :string },
              family_name: { type: :string },
              gender: { type: :string },
              birthdate: { type: :string },
              latest_identifier: { type: :string },
              identifiers: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    patient_identifier_id: { type: :integer },
                    patient_id: { type: :integer },
                    identifier: { type: :string },
                    identifier_type: { type: :string },
                    preferred: { type: :boolean },
                    location_id: { type: :integer },
                    creator: { type: :integer },
                    date_created: { type: :string },
                    voided: { type: :boolean },
                    voided_by: { type: :integer },
                    date_voided: { type: :string },
                    void_reason: { type: :string },
                    uuid: { type: :string }
                  }
                }
              }
            }
          },
          duplicate_filing_number: {
            type: :object,
            properties: {
              identifier: { type: :string },
              identifiers: { type: :integer },
              patient_ids: { type: :string }
            }
          },
          void_multiple_identifiers: {
            type: :array,
            items: { type: :integer },
            example: [1, 2, 3],
            description: 'Array of patient identifiers record ids'
          },
          patient_identifier_type: {
            type: :object,
            properties: {
              patient_identifier_type_id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              format: { type: :string },
              check_digit: { type: :integer },
              creator: { type: :integer },
              date_created: { type: :string },
              required: { type: :integer },
              format_description: { type: :string },
              validator: { type: :string },
              retired: { type: :integer },
              retired_by: { type: :integer },
              date_retired: { type: :string },
              retire_reason: { type: :string },
              uuid: { type: :string }
            }
          },
          patient_identifier: {
            type: :object,
            properties: {
              patient_identifier_id: { type: :integer },
              patient_id: { type: :integer },
              identifier: { type: :string },
              identifier_type: { type: :string },
              preferred: { type: :boolean },
              location_id: { type: :integer },
              creator: { type: :integer },
              date_created: { type: :string },
              voided: { type: :boolean },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              uuid: { type: :string },
              type: { "$ref": '#/components/schemas/patient_identifier_type' }
            }
          },
          person_attribute_type: {
            type: :object,
            properties: {
              person_attribute_type_id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              format: { type: :string },
              foreign_key: { type: :string },
              searchable: { type: :integer },
              creator: { type: :integer },
              date_created: { type: :string },
              changed_by: { type: :integer },
              date_changed: { type: :string },
              retired: { type: :integer },
              retired_by: { type: :integer },
              date_retired: { type: :string },
              retire_reason: { type: :string },
              edit_privilege: { type: :string },
              uuid: { type: :string },
              sort_weight: { type: :number }
            }
          },
          person_attribute: {
            type: :object,
            properties: {
              person_attribute_id: { type: :integer },
              person_id: { type: :integer },
              value: { type: :string },
              person_attribute_type_id: { type: :integer },
              creator: { type: :integer },
              date_created: { type: :string },
              changed_by: { type: :integer },
              date_changed: { type: :string },
              voided: { type: :integer },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              uuid: { type: :string },
              type: { "$ref": '#/components/schemas/person_attribute_type' }
            }
          },
          person_address: {
            type: :object,
            properties: {
              person_address_id: { type: :integer },
              person_id: { type: :integer },
              preferred: { type: :integer },
              address1: { type: :string },
              address2: { type: :string },
              city_village: { type: :string },
              state_province: { type: :string },
              postal_code: { type: :string },
              country: { type: :string },
              latitude: { type: :string },
              longitude: { type: :string },
              creator: { type: :integer },
              date_created: { type: :string },
              voided: { type: :integer },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              county_district: { type: :string },
              neighborhood_cell: { type: :string },
              region: { type: :string },
              subregion: { type: :string },
              township_division: { type: :string },
              uuid: { type: :string }
            }
          },
          person_name: {
            type: :object,
            properties: {
              person_name_id: { type: :integer },
              preferred: { type: :integer },
              person_id: { type: :integer },
              prefix: { type: :string },
              given_name: { type: :string },
              middle_name: { type: :string },
              family_name_prefix: { type: :string },
              family_name: { type: :string },
              family_name2: { type: :string },
              family_name_suffix: { type: :string },
              degree: { type: :string },
              creator: { type: :integer },
              date_created: { type: :string },
              voided: { type: :integer },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              changed_by: { type: :integer },
              date_changed: { type: :string },
              uuid: { type: :string }
            }
          },
          person: {
            type: :object,
            properties: {
              person_id: { type: :integer },
              gender: { type: :string },
              birthdate: { type: :string },
              birthdate_estimated: { type: :integer },
              dead: { type: :integer },
              death_date: { type: :string },
              cause_of_death: { type: :string },
              creator: { type: :integer },
              date_created: { type: :string },
              changed_by: { type: :integer },
              date_changed: { type: :string },
              voided: { type: :integer },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              uuid: { type: :string },
              names: { type: :array, items: { "$ref": '#/components/schemas/person_name' } },
              addresses: { type: :array, items: { "$ref": '#/components/schemas/person_address' } },
              patient_identifiers: { type: :array, items: { "$ref": '#/components/schemas/person_identifier' } },
              person_attributes: { type: :array, items: { "$ref": '#/components/schemas/person_attribute' } }
            }
          },
          tpt_status: {
            type: :object,
            properties: {
              tpt: { type: :string },
              completed: { type: :boolean },
              tb_treatment: { type: :boolean },
              tpt_init_date: { type: :string },
              tpt_complete_date: { type: :string }
            }
          },
          merge_audit: {
            type: :object,
            properties: {
              id: { type: :integer },
              primary_id: { type: :integer },
              secondary_id: { type: :integer },
              merge_type: { type: :string },
              secondary_previous_merge_id: { type: :integer },
              creator: { type: :integer },
              voided: { type: :boolean },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              created_at: { type: :string },
              updated_at: { type: :string }
            }
          },
          patient: {
            type: :object,
            properties: {
              patient_id: { type: :integer },
              tribe: { type: :string },
              creator: { type: :integer },
              date_created: { type: :string },
              changed_by: { type: :integer },
              date_changed: { type: :string },
              voided: { type: :integer },
              voided_by: { type: :integer },
              date_voided: { type: :string },
              void_reason: { type: :string },
              art_start_date: { type: :string },
              tpt_status: { "$ref": '#/components/schemas/tpt_status' },
              merge_history: { type: :array, items: { "$ref": '#/components/schemas/merge_audit' } },
              person: { "$ref": '#/components/schemas/person' }
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
