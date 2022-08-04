class Api::V1::OrderFrequenciesController < ApplicationController
  before_action :set_order_frequency, only: %i[show update destroy]

  # GET /order_frequencies
  def index
    @order_frequencies = OrderFrequency.all

    render json: @order_frequencies
  end

  # GET /order_frequencies/1
  def show
    render json: @order_frequency
  end

  # POST /order_frequencies
  def create
    @order_frequency = OrderFrequency.new(order_frequency_params)

    if @order_frequency.save
      render json: @order_frequency, status: :created
    else
      render json: @order_frequency.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /order_frequencies/1
  def update
    if @order_frequency.update(order_frequency_params)
      render json: @order_frequency
    else
      render json: @order_frequency.errors, status: :unprocessable_entity
    end
  end

  # DELETE /order_frequencies/1
  def destroy
    @order_frequency.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_order_frequency
    @order_frequency = OrderFrequency.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def order_frequency_params
    params.require(:order_frequency).permit(:order_frequency_id, :concept_id, :frequency_per_day, :creator,
                                            :date_created, :retired, :retired_by, :date_retired, :retire_reason, :changed_by, :date_changed, :uuid)
  end
end
