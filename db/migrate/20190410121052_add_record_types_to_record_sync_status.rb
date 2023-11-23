class AddRecordTypesToRecordSyncStatus < ActiveRecord::Migration[5.2]
  MODELS = %w[Person PersonAttribute PersonAddress PersonName Patient
              PatientIdentifier Encounter Observation Order DrugOrder
              PatientProgram PatientState].freeze

  def up
    MODELS.each do |model|
      RecordType.create(name: model)
    end
  end

  def down
    MODELS.each do |model|
      RecordType.find_by_name(model)&.destroy
    end
  end
end
