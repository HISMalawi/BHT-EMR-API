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

  private

  def save_drug_barcode(drug, quantity)
    return if DrugOrderBarcode.where(drug: drug, tabs: quantity).exists?

    DrugOrderBarcode.create(drug: drug, tabs: quantity)
  end
end
