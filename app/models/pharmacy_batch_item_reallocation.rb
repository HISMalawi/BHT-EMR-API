class PharmacyBatchItemReallocation < ApplicationRecord
  belongs_to :item, class_name: 'PharmacyBatchItem', foreign_key: :batch_item_id
  belongs_to :location, optional: true

  belongs_to :creator, foreign_key: 'creator_id', class_name: 'User'
end
