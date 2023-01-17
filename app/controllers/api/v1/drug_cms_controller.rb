# frozen_string_literal: true

# DrugCmsController is a controller class for DrugCMS
class Api::V1::DrugCmsController < ApplicationController
  before_action :set_record, except: %i[index create search]

  # Return drug_cms array of objects
  def index
    render json: paginate(DrugCms.all), status: :ok
  end

  # show specific record on drug_cms/#
  def show
    render json: @drug_cms, status: :ok
  end

  # create new drug_cms
  def create
    new_drug = DrugCms.create(create_parameters)
    handle_errors(new_drug) unless new_drug.errors.blank?
    render json: new_drug, status: :created
  end

  # update specific drug_cms/#
  def update
    update_drug_cms = @drug_cms.update(update_parameters)
    handle_errors(@drug_cms) unless update_drug_cms
    render json: @drug_cms, status: :ok
  end

  # search drug_cms using param[:keyword]
  def search
    kwd = params[:keyword]
    if kwd.present?
      render json: service.search_drug_cms(kwd), status: :ok
    else
      render json: []
    end
  end

  # destroy
  def destroy
    reason = params.require(:reason)
    @drug_cms.void(reason)
    render json: { message: 'Removed successfully' }, status: :ok
  end

  private

  def service
    DrugCmsService.new
  end

  def set_record
    @drug_cms = DrugCms.find(params[:id])
  end

  def handle_errors(model)
    error = InvalidParameterError.new('Failed to Updated Record')
    error.model_errors = model.errors
    raise error
  end

  def update_parameters
    params.permit(:id, :code, :drug_inventory_id, :name, :short_name, :tabs, :pack_size, :weight, :strength)
  end

  def create_parameters
    params.permit(:code, :drug_inventory_id, :name, :short_name, :tabs, :pack_size, :weight, :strength)
  end
end
