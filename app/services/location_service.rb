# frozen_string_literal: true

class LocationService
  # Outputs label printer commands for printing out a location label
  def print_location_label(location)
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, location.location_id.to_s)
    label.draw_multi_text(location.name.to_s)
    label.print(1)
  end
end
