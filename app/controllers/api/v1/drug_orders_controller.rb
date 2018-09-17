class Api::V1::DrugOrdersController < ApplicationController
  def index
    params.permit(%i[drug_inventory_id])
  end
end
