# frozen_string_literal: true

class EmrOhspInterface::EmrLimsInterfaceController < ::ApplicationController
  def create
    # lab_details = params.require %i[lab_details]
    # render json: "#{lab_details[0]['firstname']}"
    # render json:
    order_params_list, clinician_id = params.require %i[lab_details clinician_id]

    render json: service.create_lab_order(order_params_list, clinician_id)
  end

  def index
    render json: service.get_lims_test_results(params[:id],params[:patient_id])
  end

  def get_user_info()
    render json: service.get_user_details(params[:id])
  end

  def service
    EmrOhspInterface::EmrLimsInterfaceService
  end
end
