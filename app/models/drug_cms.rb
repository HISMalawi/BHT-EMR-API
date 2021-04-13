# frozen_string_literal: true

class DrugCms < ApplicationRecord
  self.table_name = :drug_cms
  self.primary_key = :drug_inventory_id

  belongs_to :drug, foreign_key: :drug_inventory_id
end
