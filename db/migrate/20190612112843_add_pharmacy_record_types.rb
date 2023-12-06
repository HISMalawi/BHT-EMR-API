class AddPharmacyRecordTypes < ActiveRecord::Migration[5.2]
  MODELS = [Pharmacy, PharmacyBatch, PharmacyBatchItem,
            PharmacyBatchItemReallocation].freeze

  def up
    MODELS.each do |model|
      RecordType.create(name: model.to_s)
    end
  end

  def down
    MODELS.each do |model|
      RecordType.find_by_name(model.to_s)&.destroy
    end
  end
end
