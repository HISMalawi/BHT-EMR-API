# frozen_string_literal: true

class AddMissingAlternativeArvNames < ActiveRecord::Migration[5.2]
  def up
    Drug.arv_drugs.each do |drug|
      next unless drug.alternative_names.empty?

      name = drug.name.strip
      name.gsub!(/([a-z]+)(\d+)/i, '\1 \2') # Separate numbers from words
      name.gsub!(/([a-z0-9]*)([&+-\/\\])([a-z0-9]*)/i, '\1 \2 \3') # Separate symbols (separators) from everything else

      AlternativeDrugName.create(
        name: name,
        short_name: name,
        drug_inventory_id: drug.id
      )
    end
  end

  def down
    # Original alternative names are populated from drug_cms table
    execute <<~SQL
      DELETE FROM alternative_drug_names WHERE drug_inventory_id NOT IN (
        SELECT drug_inventory_id FROM drug_cms
      )
    SQL
  end
end
