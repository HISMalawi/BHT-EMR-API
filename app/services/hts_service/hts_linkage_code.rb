module HTSService
  class HtsLinkageCode

    HTS_LINK_CODE_CONCEPT = ConceptName.find_by_name('HTC serial number').concept_id

    attr_reader :patient_id, :code

    def initialize patient_id, code
      @patient_id = patient_id
      @code = code
    end

    def hts_linkage_code
      code
    end

    def print_linkage_code
      return if hts_linkage_code.nil?

      person_name = PersonName.find_by(person_id: @patient_id)
      name = "#{person_name.given_name} #{person_name.family_name}"
      label = ZebraPrinter::StandardLabel.new
      label.draw_text(name, 40, 10, 0, 2, 2, 2, false)
      label.draw_text('HTS LINK CODE', 40, 60, 0, 2, 2, 2, false)
      label.draw_text(hts_linkage_code, 40, 120, 0, 2, 2, 2, false)
      label.draw_barcode(50, 180, 0, 1, 5, 15, 120, false, hts_linkage_code)
      label.print(1)
    end
  end
end