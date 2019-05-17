class PharmacyBatchItemReallocation < ApplicationRecord
  belongs_to :item, class_name: 'PharmacyBatchItem', foreign_key: :batch_item_id
  belongs_to :location
end
