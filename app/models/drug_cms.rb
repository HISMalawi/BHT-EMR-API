# frozen_string_literal: true

class DrugCms < VoidableRecord
  self.table_name = :drug_cms
  self.primary_key = :id

  belongs_to :drug, foreign_key: :drug_inventory_id
  validates :name, presence: true, uniqueness: true
  validates :short_name, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :pack_size, presence: true, numericality: {only_integer: true, greater_than: 0}
end
