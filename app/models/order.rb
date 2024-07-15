# frozen_string_literal: true

class Order < VoidableRecord
  self.table_name = :orders
  self.primary_key = :order_id

  after_void :void_records

  belongs_to :order_type
  belongs_to :concept
  belongs_to :encounter
  belongs_to :patient
  belongs_to :provider, foreign_key: 'orderer', class_name: 'User', optional: true

  validates_presence_of :patient_id, :concept_id, :encounter_id,
                        :provider, :orderer
  has_many :observations
  has_one :lims_acknowledgement_status, foreign_key: :order_id
  has_one :drug_order

  validate :start_date

  # basically we want to ensure the data being saved is sanitized
  def start_date_cannot_be_in_the_future
    return unless start_date > Time.now

    errors.add(:start_date, ' cannot be in the future')
  end

  def void_records
    clear_associated_obs(void_reason)
    clear_dispensed_drugs(void_reason)
  end

  def clear_dispensed_drugs(void_reason)
    lims_acknowledgement_status&.void(void_reason)
    return unless drug_order

    drug_order.quantity = 0
    # Skip validations which check for existence of order, in this case we have just voided it
    # so it doesn't exist.
    drug_order.save(validate: false)
  end

  def clear_associated_obs(void_reason)
    observations.each do |obs|
      obs.void(void_reason)
    end
  end
end
