class OrderTypeClassMap < ApplicationRecord
  belongs_to :order_type
  belongs_to :concept_class
end
