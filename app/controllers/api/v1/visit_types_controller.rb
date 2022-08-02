class VisitTypesController < ApplicationController
  before_action :set_visit_type, only: %i[show update destroy]

  # GET /visit_types
  def index
    @visit_types = VisitType.all

    render json: @visit_types
  end

  # GET /visit_types/1
  def show
    render json: @visit_type
  end

  # POST /visit_types
  def create
    @visit_type = VisitType.new(visit_type_params)

    if @visit_type.save
      render json: @visit_type, status: :created, location: @visit_type
    else
      render json: @visit_type.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /visit_types/1
  def update
    if @visit_type.update(visit_type_params)
      render json: @visit_type
    else
      render json: @visit_type.errors, status: :unprocessable_entity
    end
  end

  # DELETE /visit_types/1
  def destroy
    @visit_type.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_visit_type
    @visit_type = VisitType.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def visit_type_params
    params.require(:visit_type).permit(:name, :description, :creator, :date_created, :changed_by, :date_changed,
                                       :retired, :retired_by, :date_retired, :retire_reason, :uuid)
  end
end
