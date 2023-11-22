# frozen_string_literal: true

class DrugOrderBarcode < ApplicationRecord
  self.table_name = :drug_order_barcodes
  self.primary_key = :drug_order_barcode_id

  belongs_to :drug
end
