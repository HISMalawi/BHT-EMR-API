# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join("swagger").to_s

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
          multiple_filing_numbers: {
            type: :object,
            properties: {
              person_id: { type: :integer },
              given_name: { type: :string },
              family_name: { type: :string },
              gender: { type: :string },
              birthdate: { type: :string },
              arv_number: { type: :string },
              identifiers: { type: :integer },
              filing_numbers: { type: :string }
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
          void_mutliple_filing_numbers: {
            type: :object,
            properties: {
              identifier: { type: :string },
              patient_id: { type: :integer },
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
