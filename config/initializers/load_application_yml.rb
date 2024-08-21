# frozen_string_literal: true

# config/initializers/load_application_yml.rb
config = YAML.safe_load(File.read(Rails.root.join('config', 'application.yml')), aliases: true)[Rails.env]
(config || {}).each do |key, value|
  ENV[key.upcase] ||= value.to_s
end
