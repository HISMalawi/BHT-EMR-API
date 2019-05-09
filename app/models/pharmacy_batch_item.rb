# frozen_string_literal: true

class PharmacyBatchItem < VoidableRecord
  belongs_to :batch, class_name: 'PharmacyBatch', foreign_key: 'pharmacy_batch_id'
  belongs_to :drug

  validates_each :delivered_quantity, :current_quantity do |record, attr, value|
    record.errors.add(attr, "Quantity can't be less than 0") if value.negative?
  end
end
