class Api::V1::DrugCmsController < ApplicationController
  #before_action :authenticate, except: %i[index create update show search]

  def index
    render json: paginate(drug_cms_service.get_all_drug_cms)
  end

  def create
    render json: drug_cms_service.create_drug_cms(params)
  end

  def update
    if update_parameters[:id].present?
      render json: drug_cms_service.update_drug_cms(update_parameters)
    else
      render json: nil
    end
  end

  def show
    id = params.require(:id)
    render json: drug_cms_service.get_drug_cms(params)
  end

  def search
    kwd = params[:keyword]
    if kwd.present?
      render json: paginate(drug_cms_service.search_drug_cms(kwd))
    else
      render json: []
    end
  end

  private
  def drug_cms_service
    DrugCmsService.new
  end

  def update_parameters
    params.permit(
      :id,
      :code,
      :drug_inventory_id,
      :name,
      :short_name,
      :tabs,
      :pack_size,
      :weight,
      :strength
    )
  end
end
