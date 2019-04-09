# frozen_string_literal: true

CONFIG_PATH = Rails.root.join('config/database.yml').to_s
STATE_PATH = Rails.root.join('cache/state.json').to_s

MODEL_NAMES = %w[Person PersonAttribute PersonAddress PersonName
                 Patient PatientIdentifier Encounter Obs Orders DrugOrder
                 PatientProgram PatientState].freeze

class LegacyEncounterWrapper
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def where(*args, **kwargs)
    model.where(*args, **kwargs)
  end

  def as_json
    hash = encounter.as_json
    hash[:program_id] = program(config('program_name')).program_id
    hash
  end
end

# Load database configuration
def load_config
  YAML.load_file(CONFIG_PATH)
end

# Loads last update time read
def load_state
end

MODEL_NAMES.each do |name|
  # 1. Select all records with recent changes
  # 2. Cache most recent time somewhere if it's greater than currently cached time
  # 3. Push record (as hash) to datastore

  recent_records(model(name), delta) do |record|
    save_delta(record.updated_at) if record.updated_at > delta
    push_record(config, name, record)
  end
end

def recent_records(model, delta)
  records = model.where('updated_at > ?', delta)
  return records unless block_given?

  records.each { |record| yield(record) }
end

def model(name)
  # 1. Check if name is Encounter and we are using an external
end
