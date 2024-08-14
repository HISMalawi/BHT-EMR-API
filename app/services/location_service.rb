# frozen_string_literal: true

class LocationService
  # Outputs label printer commands for printing out a location label
  def print_location_label(location)
    label = ZebraPrinter::Lib::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, location.location_id.to_s)
    label.draw_multi_text(location.name.to_s)

    {
      zpl: label.print(1),
      data: {
        barcode: location.location_id.to_s,
        location_id: location.location_id,
        location_name: location.name,
      },
    }
  end
end
