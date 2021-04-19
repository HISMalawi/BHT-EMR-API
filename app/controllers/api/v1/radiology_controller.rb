
require 'zebra_printer/init'
class Api::V1::RadiologyController < ApplicationController
  before_action :authenticate, except: %i[print_barcode ]

  def create
    patient_details, physician_details, radiology_orders = params.require %i[patient_details physician_details radiology_orders]
    radiology_orders = service.generate_msi(patient_details,physician_details, radiology_orders)
    render json: radiology_orders, status: :created
  end
  def print_barcode
    printer_commands = service.print_radiology_barcode(params[:accession_number],params[:patient_national_id], params[:patient_name], params[:radio_order], params[:date_created])
    send_data(printer_commands, type: 'application/label; charset=utf-8',
                                stream: false,
                                filename: "#{SecureRandom.hex(24)}.lbl",
                                disposition: 'inline')
  end
  def service
    RadiologyService
  end
end
