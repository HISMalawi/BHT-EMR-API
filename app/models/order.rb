# frozen_string_literal: true

class Order < VoidableRecord
  self.table_name = :orders
  self.primary_key = :order_id

  after_void :clear_dispensed_drugs

  belongs_to :order_type
  belongs_to :concept
  belongs_to :encounter
  belongs_to :patient
  belongs_to :provider, foreign_key: 'orderer', class_name: 'User', optional: true

  validates_presence_of :patient_id, :concept_id, :encounter_id,
                        :provider, :orderer
  has_many :observations
  has_one :drug_order

  def clear_dispensed_drugs(_void_reason)
    return unless drug_order

    drug_order.quantity = 0
    drug_order.save
  end
end
