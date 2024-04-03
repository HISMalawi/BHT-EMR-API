# frozen_string_literal: true

require 'rswag/ui'

Rswag::Ui.configure do |c|
  c.openapi_endpoint '/api-docs/lab/v1/swagger.yaml', 'Lab API V1 Docs'
end
