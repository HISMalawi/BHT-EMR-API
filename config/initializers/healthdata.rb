# frozen_string_literal: true

Rails.application.config.healthdata_db = YAML.load(
  ERB.new(
    File.read(Rails.root.join('config', 'database.yml'))
  ).result
)['healthdata']
