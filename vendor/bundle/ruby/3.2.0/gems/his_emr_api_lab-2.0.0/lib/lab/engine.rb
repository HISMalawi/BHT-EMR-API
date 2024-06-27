# frozen_string_literal: true

if Rails.env == 'test'
  require 'rswag/ui'
  require 'rswag/api'
end

module Lab
  class Engine < ::Rails::Engine
    isolate_namespace Lab
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
