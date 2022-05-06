# frozen_string_literal: true

yaml_config = ERB.new(
  File.read(Rails.root.join('config', 'database.yml'))
).result
database_config = YAML.unsafe_load(yaml_config)
Rails.application.config.healthdata_db = database_config['healthdata']
