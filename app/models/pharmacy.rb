# frozen_string_literal: true

class Pharmacy < VoidableRecord
  self.table_name = :pharmacy_obs
  self.primary_key = :pharmacy_module_id
end
