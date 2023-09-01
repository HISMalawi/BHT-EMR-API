class Api::V1::Pharmacy::StockVerificationsController < ApplicationController
  before_action :set_pharmacy_stock_verification, only: [:show, :update, :destroy]

  # GET /pharmacy_stock_verifications
  def index
    @pharmacy_stock_verifications = PharmacyStockVerification.all

    render json: @pharmacy_stock_verifications
  end

  # GET /pharmacy_stock_verifications/1
  def show
    render json: @pharmacy_stock_verification
  end

  # POST /pharmacy_stock_verifications
  def create
    @pharmacy_stock_verification = PharmacyStockVerification.new(pharmacy_stock_verification_params)

    if @pharmacy_stock_verification.save
      render json: @pharmacy_stock_verification, status: :created, location: @pharmacy_stock_verification
    else
      render json: @pharmacy_stock_verification.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /pharmacy_stock_verifications/1
  def update
    if @pharmacy_stock_verification.update(pharmacy_stock_verification_params)
      render json: @pharmacy_stock_verification
    else
      render json: @pharmacy_stock_verification.errors, status: :unprocessable_entity
    end
  end

  # DELETE /pharmacy_stock_verifications/1
  def destroy
    @pharmacy_stock_verification.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_pharmacy_stock_verification
      @pharmacy_stock_verification = PharmacyStockVerification.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def pharmacy_stock_verification_params
      params.require(:pharmacy_stock_verification).permit(:reason, :verification_date, :creator, :date_created, :changed_by, :date_changed, :voided, :voided_by, :void_reason, :date_voided)
    end
end
