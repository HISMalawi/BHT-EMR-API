# frozen_string_literal: true

# encaspulating module
module RadiologyService
  # module handling printing of an order
  class OrderLabel
    def initialize(params)
      @order = Order.find_by(params)
    end

    def print
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 4
      label.x = 200
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 100
      label.draw_barcode(100, 220, 0, 1, 5, 15, 90, false, @order.accession_number.to_s)
      label.draw_multi_text(@order.patient.person.name)
      label.draw_multi_text("#{@order.patient.national_id_with_dashes} #{@order.patient.person.gender} #{@order.patient.person.birthdate}")
      if detailed_examination.blank?
        label.draw_multi_text("#{order_type}-#{examination}")
      else
        label.draw_multi_text("#{order_type}-#{examination}-#{detailed_examination}")
      end
      label.draw_multi_text("#{session_date}, #{@order.accession_number} (#{referred_from})")
      label.print(1)
    end

    def examination
      return @examination if @examination

      examination_concept = ConceptName.find_by_name("EXAMINATION").concept_id
      examination_obs = Observation.find_by(concept_id: examination_concept, encounter_id: @order.encounter_id)
      examination = examination_obs.answer_concept.shortname rescue ''

      if examination.blank?
        examination = examination_obs.answer_concept.fullname rescue ''
      end
      @examination = examination
    end

    def session_date
      @session_date ||= @order.start_date.strftime('%d-%b-%Y')
    end

    def detailed_examination
      return @detailed_examination if @detailed_examination

      detailed_examination_concept = ConceptName.find_by_name('DETAILED EXAMINATION').concept_id
      detailed_examination_obs = Observation.find_by(concept_id: detailed_examination_concept, encounter_id: @order.encounter_id)
      @detailed_examination ||= detailed_examination_obs&.answer_concept&.shortname || detailed_examination_obs&.answer_concept&.fullname
    end

    def order_type
      @order_type ||= @order.concept.shortname || @order.concept.fullname
    end

    def referred_from
      referred_from_concept = ConceptName.find_by_name('REFERRED FROM').concept_id
      referred_from = @order.encounter.observations.find_by(concept_id: referred_from_concept)&.value_text
      referred_from.blank? ? 'Unknown' : referred_from
    end
  end
end