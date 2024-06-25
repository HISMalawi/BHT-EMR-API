# frozen_string_literal: true
require 'zebra_printer/init'
class Radiology::RadiologyController < ::ApplicationController
  before_action :authenticate, except: %i[print_order_label ]
  def create
    patient_details, physician_details, radiology_orders = params.require %i[patient_details physician_details radiology_orders]
    radiology_orders = service.generate_msi(patient_details,physician_details, radiology_orders)
    render json: radiology_orders, status: :created
  end
  def show
    render json: service.get_radiology_orders(params[:id])
  end

  def index
    render json: service.get_previous_orders(params[:patient_id])
  end

  def print_order_label
    label = service.print_radiology_barcode(params[:accession_number],params[:patient_national_id], params[:patient_name], params[:radio_order], params[:date_created])
    send_data(label, type: 'application/label; charset=utf-8',
                           stream: false,
                           filename: "#{SecureRandom.hex(24)}.lbl",
                           disposition: 'inline')
  end
  def service
    Radiology::RadiologyService
  end
end
