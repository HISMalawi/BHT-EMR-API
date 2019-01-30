require 'securerandom'

class Api::V1::DrugsController < ApplicationController
  before_action :authenticate, except: %i[print_barcode]
  def show
    render json: Drug.find(params[:id])
  end

  def index
    name = params.permit(:name)[:name]
    query = name ? Drug.where('name like ?', "#{name}%") : Drug
    render json: paginate(query)
  end

  def print_barcode
    quantity = params.require(:quantity)
    printer_commands = service.print_drug_barcode(drug, quantity)
    send_data(printer_commands, type: 'application/label; charset=utf-8',
                                stream: false,
                                filename: "#{SecureRandom.hex(24)}.lbl",
                                disposition: 'inline')
  end

  private

  def drug
    Drug.find(params[:drug_id])
  end

  def service
    DrugService.new
  end
end
