# frozen_string_literal: true

module TbService
  class PatientTransferOutLabel
    def initialize(patient, date)
      @patient = patient
      @date = date
      @note = TbService::PatientTransferOut.new @patient, @date
      @printer = printer_instance
    end

    def print
      writelines
      @printer.print(1)
    end

    private

    def printer_instance
      printer = ZebraPrinter::Lib::Label.new(776, 329, 'T')
      printer.line_spacing = 0
      printer.top_margin = 30
      printer.bottom_margin = 30
      printer.left_margin = 25
      printer.x = 25
      printer.y = 30
      printer.font_size = 3
      printer.font_horizontal_multiplier = 1
      printer.font_vertical_multiplier = 1

      printer
    end

    def writelines
      # Patient personal data
      @printer.draw_multi_text("#{health_center} transfer out label", font_reverse: true)
      @printer.draw_multi_text("To #{@note.transferred_out_to}", font_reverse: false)
      @printer.draw_multi_text(demographics_str, font_reverse: false)

      # Print patient program information!
      @printer.draw_multi_text("TB start date: #{start_date}", font_reverse: false)
      @printer.draw_multi_text("Transfer out date: #{transfer_date}", font_reverse: false)
      @printer.draw_multi_text('Current regimen', font_reverse: true)
      @printer.draw_multi_text(@note.current_regimen, font_reverse: false)
      @printer.draw_multi_text('Drugs dispensed today', font_reverse: true)
      @printer.draw_multi_text(@note.drugs_dispensed, font_reverse: false)
    end

    def start_date
      @note.enrollment_date&.strftime('%d-%b-%Y')
    end

    def transfer_date
      @note.transfer_out_date&.strftime('%d-%b-%Y')
    end

    def health_center
      Location.current_health_center.name
    end

    def demographics_str
      "Name: #{@patient.name} (#{@patient.gender.first})\nAge: #{@patient.age}"
    end
  end
end
