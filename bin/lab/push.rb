# frozen_string_literal: true

api = Lab::Lims::Api.new
worker = Lab::Lims::Worker.new(api)
worker.push_orders
