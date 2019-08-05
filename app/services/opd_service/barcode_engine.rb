# frozen_string_literal: true

require 'zebra_printer/lib/zebra_printer'

class OPDService::BarcodeEngine
  def initialize(program: nil)
    @program = program
  end

  def la_report_barcode(params)
    label = ZebraPrinter::StandardLabel.new
    label.draw_line(30,85,740,3,0)
    label.draw_text('Prescribed', 220, 55, 0, 1, 2, 2, false)
    label.draw_text('Dispensed', 540, 55, 0, 1, 2, 2, false)
    label.draw_text('AL1', 50, 100, 0, 1, 2, 2, false)
    label.draw_text("#{params['1'][:prescription]}", 250,100, 0, 4, 1, 1, false)
    label.draw_text("#{params['1'][:dispensed]}", 580, 100, 0, 4, 1, 1, false)
    label.draw_text('AL2', 50, 140, 0, 1, 2, 2,false)
    label.draw_text("#{params['2'][:prescription]}", 250,140, 0, 4, 1, 1, false)
    label.draw_text("#{params['2'][:dispensed]}", 580, 140, 0, 4, 1, 1, false)
    label.draw_text('AL3', 50, 170, 0, 1, 2, 2,false)
    label.draw_text("#{params['3'][:prescription]}", 250,170, 0, 4, 1, 1, false)
    label.draw_text("#{params['3'][:dispensed]}", 580, 170, 0, 4, 1, 1, false)
    label.draw_text('AL4', 50, 200, 0, 1, 2, 2,false)
    label.draw_text("#{params['4'][:prescription]}", 250,200, 0, 4, 1, 1, false)
    label.draw_text("#{params['4'][:dispensed]}", 580, 200, 0, 4, 1, 1, false)
    label.draw_line(30, 245, 740, 3, 0)
    time = DateTime.now
    label.draw_text("Date: #{params['date'][:start]} to #{params['date'][:end]}", 30, 20, 0, 2, 1, 1,false)
    label.draw_text("Time: #{time.strftime("%Y-%m-%d %H:%M:%S")}", 500, 20, 0, 2, 1, 1,false)
    label.print(1)
  end
end
