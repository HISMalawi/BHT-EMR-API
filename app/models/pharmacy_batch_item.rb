# frozen_string_literal: true

class PharmacyBatchItem < VoidableRecord
  belongs_to :batch, class_name: 'PharmacyBatch', foreign_key: 'pharmacy_batch_id'
  belongs_to :drug

  has_many :transactions, class_name: 'Pharmacy', inverse_of: :item

  validates_each :delivered_quantity, :current_quantity do |record, attr, value|
    record.errors.add(attr, "Quantity can't be less than 0") if value.negative?
  end

  def as_json(options = {})
    super(options.merge(methods: %i[drug_name]))
  end

  def creator_id
    method(:creator).super_method.call
  end

  def creator
    user = User.unscoped.find_by(user_id: creator_id)
    person_name = PersonName.where(person_id: creator_id).first

    {
      username: user&.username,
      given_name: person_name&.given_name,
      family_name: person_name&.family_name
    }
  end

  def drug_name
    drug.name
  end
end
