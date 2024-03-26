# frozen_string_literal: true

class DrugSet < ApplicationRecord
  self.table_name = :drug_set
  self.primary_key = :drug_set_id

  belongs_to :dset, -> { where(voided: 0) }, foreign_key: :set_id, optional: true

  def void
    update_attributes(voided: 1)
  end
end
