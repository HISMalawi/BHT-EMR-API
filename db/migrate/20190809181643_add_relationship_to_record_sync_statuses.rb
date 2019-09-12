class AddRelationshipToRecordSyncStatuses < ActiveRecord::Migration[5.2]
  MODELS = %w[Relationship].freeze

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
