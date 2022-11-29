class Api::V1::DrugCmsController < ApplicationController
  before_action :get_record, except: %i[index create search]

  #Return drug_cms array of objects
  def index
    render json: paginate(DrugCms.all)
  end

  #show specific record on drug_cms/#
  def show
    id = params.require(:id)
    render json: @found_record
  end

  #create new drug_cms
  def create
    new_drug = DrugCms.create(create_parameters)
    handle_errors(new_drug) unless new_drug.errors.blank?
    render json: new_drug
  end

  #update specific drug_cms/#
  def update
    update_drug_cms = @found_record.update(update_parameters)
    handle_errors(@found_record) unless update_drug_cms
    render json: @found_record
  end

  #search drug_cms using param[:keyword]
  def search
    kwd = params[:keyword]
    if kwd.present?
      render json: paginate(drug_cms_service.search_drug_cms(kwd))
    else
      render json: []
    end
  end

  #destroy
  def destroy
    reason = params.require(:reason)
    @found_record.void(reason)
    render json: {message: 'Removed successfully'}, status: :ok
  end

  private
  def drug_cms_service
    DrugCmsService.new
  end

  def get_record
    @found_record = DrugCms.find(params[:id])
  end

  def handle_errors(model)
    error = InvalidParameterError.new("Failed to Updated Record")
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
