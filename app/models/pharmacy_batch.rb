# frozen_string_literal: true

class PharmacyBatch < VoidableRecord
  has_many :items, class_name: 'PharmacyBatchItem'

  after_void :void_items

  def as_json(options = {})
    super(options.merge(
      include: {
        items: {
          methods: %i[drug_name]
        }
      }
    ))
  end

  def void_items(reason)
    items.each { |item| item.void(reason) }
  end
end
