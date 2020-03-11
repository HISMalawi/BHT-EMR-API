# frozen_string_literal: true

class DrugService
  # Outputs label printer commands for printing drug barcodes.
  def print_drug_barcode(drug, quantity)
    drug_barcode = "#{drug.id}-#{quantity}"

    label = ZebraPrinter::StandardLabel.new

    if drug.name.length <= 27
      label.draw_text(drug.name.to_s, 40, 30, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{quantity}", 40, 80, 0, 2, 2, 2, false)
      label.draw_barcode(40, 130, 0, 1, 5, 15, 120, true, drug_barcode.to_s)
    else
      label.draw_text(drug.name[0..25], 40, 30, 0, 2, 2, 2, false)
      label.draw_text(drug.name[26..-1], 40, 80, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{quantity}", 40, 130, 0, 2, 2, 2, false)
      label.draw_barcode(40, 180, 0, 1, 5, 15, 100, true, drug_barcode.to_s)
    end

    save_drug_barcode(drug, quantity)
    label.print(1)
  end

  def stock_levels(classification)
    return classification == 'peads' ? stock_levels_graph_paeds : stock_levels_graph_adults
  end

  def find_drugs(filters)
    filters = filters.dup # May be modified
    query = Drug.all

    if filters.include?(:concept_set)
      concept_set = filters.delete(:concept_set)
      query = query.joins('INNER JOIN concept_set ON drug.concept_id = concept_set.concept_id')
                   .joins('INNER JOIN concept_name ON concept_set.concept_set = concept_name.concept_id')
                   .where('concept_name.name LIKE ?', concept_set)
    end

    if filters.include?(:name)
      name = filters.delete(:name)
      query = query.where('name LIKE ?', "#{name}%")
    end

    query = query.where(filters) unless filters.empty?
    query.order(:name)
  end

  private

  def save_drug_barcode(drug, quantity)
    return if DrugOrderBarcode.where(drug: drug, tabs: quantity).exists?

    DrugOrderBarcode.create(drug: drug, tabs: quantity)
  end

  def stock_levels_graph_adults
  end

  def stock_levels_graph_paeds
    list = {}
    paeds_drug_ids = [733, 968, 732, 736, 30, 74, 979, 963, 24]
    paediatric_drugs = DrugCms.where(["drug_inventory_id IN (?)", paeds_drug_ids])
    paediatric_drugs.each do |drug_cms|

      drug = Drug.find(drug_cms.drug_inventory_id)
      drug_pack_size = drug_cms.pack_size #Pharmacy.pack_size(drug.id)
      current_stock = (Pharmacy.latest_drug_stock(drug.id)/drug_pack_size).to_i #In tins
      consumption_rate = Pharmacy.average_drug_consumption(drug.id)

      stock_level = current_stock
      disp_rate = ((30 * consumption_rate)/drug_pack_size).to_f #rate is an avg of pills dispensed per day. here we convert it to tins per month
      consumption_rate = ((30 * consumption_rate)/drug_pack_size) #rate is an avg of pills dispensed per day. here we convert it to tins per month

      expected = stock_level.round
      month_of_stock = (expected/consumption_rate) rescue 0
      stocked_out = (disp_rate.to_i != 0 && month_of_stock.to_f.round(3) == 0.00)

      active = (disp_rate.to_i == 0 && stock_level.to_i != 0)? false : true
      drug_cms_name = "#{drug_cms.short_name} (#{drug_cms.strength})"

      stock_expiry_date = Pharmacy.latest_expiry_date_for_drug(drug.id)
      date_diff_in_months = 0
      unless stock_expiry_date.blank? #Date diff in months
        date_diff_in_months = (stock_expiry_date.year * 12 + stock_expiry_date.month) - (Date.today.year * 12 + Date.today.month)
        if (date_diff_in_months > 0 && date_diff_in_months < month_of_stock)

        else
          date_diff_in_months = 0
          #raise stock_expiry_date.inspect
        end

      end

      date_diff_in_months = 0 if disp_rate.to_i == 0
      month_of_stock = month_of_stock - date_diff_in_months

      @list[drug_cms_name] = {
        "month_of_stock" => month_of_stock,
        "stock_level" => stock_level,
        "drug" => drug.id,
        "consumption_rate" => (disp_rate.round(2)),
        "stocked_out" => stocked_out,
        "expiry_stock" => date_diff_in_months,
        "active" => active
      }

    end
    @list = @list.sort_by{|k, v|k}

    render :layout => false
  end

end
