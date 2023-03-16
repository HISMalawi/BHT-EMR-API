# frozen_string_literal: true

# DrugCmsService is a service class for DrugCMS
class DrugCmsService
  def search_drug_cms(kwd)
    ActiveRecord::Base.connection.select_all <<~SQL
      SELECT dc.*
      FROM drug_cms dc
      INNER JOIN arv_drug ad ON ad.drug_id = dc.drug_inventory_id
      WHERE dc.name LIKE '%#{kwd}%' OR dc.code LIKE '%#{kwd}%' OR dc.short_name LIKE '%#{kwd}%'
    SQL
  end
end
