# frozen_string_literal: true

class PharmacyBatchVvm < VoidableRecord
  belongs_to :item, class_name: 'PharmacyBatchItem', foreign_key: :batch_item_id
  validates :vvm, presence: true
end