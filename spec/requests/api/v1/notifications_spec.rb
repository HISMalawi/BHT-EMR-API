# frozen_string_literal: true

require 'swagger_helper'

TAG = 'Notification Endpoints'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'api/v1/notifications', type: :request do
  path '/api/v1/notifications/clear/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    put('clear notification') do
      tags TAG
      description 'Clear notification'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      response(200, 'successful') do
        let(:id) { '123' }
        schema type: :object, properties: {
          success: { type: :boolean }
        }
        run_test!
      end
    end
  end

  path '/api/v1/notifications' do
    get('list notifications') do
      tags TAG
      description 'List Uncleared notifications'
      consumes 'application/json'
      produces 'application/json'
      response(200, 'successful') do
        schema type: :array, items: { '$ref' => '#/components/schemas/notification_alert' }
        run_test!
      end
    end
  end

  path '/api/v1/notifications/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    put('update notification') do
      tags TAG
      description 'Update notification'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      response(200, 'successful') do
        let(:id) { '123' }
        schema type: :object, properties: {
          success: { type: :boolean }
        }
        run_test!
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
