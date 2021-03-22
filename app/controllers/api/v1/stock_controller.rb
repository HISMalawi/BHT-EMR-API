# frozen_string_literal: true

class Api::V1::StockController < ApplicationController
  # Create a new set of drug stock
  #
  # POST /stock {
  #     obs: [{drug_id:, delivery_date:, amount:, expire_amount:, identifier:,}, ...]
  # }
  #
  def create
    stock_obs = params.require(:obs)
    stocks = service.create_stocks(stock_obs)

    render json: stocks, status: :created
  end

  def edit
    stock_obs = params.require(:obs)

    render json: service.edit_stock_report(stock_obs)
  end

  private

  def service
    StockManagementService.new
  end
end
