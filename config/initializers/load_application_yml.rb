# config/initializers/load_application_yml.rb
config = YAML.load_file(Rails.root.join('config', 'application.yml'))[Rails.env]
config.each do |key, value|
  ENV[key.upcase] ||= value
end
