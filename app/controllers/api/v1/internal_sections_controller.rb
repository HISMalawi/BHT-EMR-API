class Api::V1::InternalSectionsController < ApplicationController
  before_action :set_internal_section, only: %i[show update destroy]

  # GET /internal_sections
  def index
    @internal_sections = InternalSection.all

    render json: paginate(@internal_sections)
  end

  # GET /internal_sections/1
  def show
    render json: @internal_section
  end

  # POST /internal_sections
  def create
    @internal_section = InternalSection.new(internal_section_params)

    if @internal_section.save
      render json: @internal_section, status: :created
    else
      render json: @internal_section.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /internal_sections/1
  def update
    if @internal_section.update(internal_section_params)
      render json: @internal_section, status: :ok
    else
      render json: @internal_section.errors, status: :unprocessable_entity
    end
  end

  # DELETE /internal_sections/1
  def destroy
    @internal_section.void(params.require(:void_reason))
    render json: { message: 'Removed' }, status: :ok
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_internal_section
    @internal_section = InternalSection.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def internal_section_params
    params.permit(:name)
  end
end
