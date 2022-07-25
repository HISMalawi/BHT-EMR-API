# frozen_string_literal: true

# encaspulating module
module RadiologyService
  # module handling printing of an order
  class OrderLabel
    def initialize(order_id)
      @order = Order.find(order_id)
    end

    def print
      type = @order.concept.shortname || @order.concept.fullname
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 4
      label.x = 200
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 100
      label.draw_barcode(100, 220, 0, 1, 5, 15, 90, false, order.accession_number.to_s)
      label.draw_multi_text(@order.patient.person.name)
      label.draw_multi_text("#{@order.patient.national_id_with_dashes} #{@order.patient.person.gender} #{@order.patient.person.birth_date}")
      if detailed_examination.blank?
        label.draw_multi_text("#{type}-#{examination}")
      else
        label.draw_multi_text("#{type}-#{examination}-#{detailed_examination}")
      end
      label.draw_multi_text("#{session_date}, #{order.accession_number} (#{referred_from})")
      label.print(1)
    end

    def referred_from
      referred_from_concept = ConceptName.find_by_name('REFERRED FROM').concept_id
      referred_from = @order.encounter.observations.find_by(concept_id: referred_from_concept)&.value_text
      referred_from.blank? ? 'Unknown' : referred_from
    end
  end
end
