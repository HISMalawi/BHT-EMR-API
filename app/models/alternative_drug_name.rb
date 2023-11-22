# frozen_string_literal: true

class AlternativeDrugName < ApplicationRecord
  validates_presence_of :name, :drug_inventory_id

  belongs_to :drug, foreign_key: :drug_inventory_id
end
