if Rails.env == 'test'
  require 'rswag/ui'
  require 'rswag/api'
end

module Radiology
  class Engine < ::Rails::Engine
    isolate_namespace Radiology
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end