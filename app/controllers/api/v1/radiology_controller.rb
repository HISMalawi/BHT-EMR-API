
class Api::V1::RadiologyController < ApplicationController

  def create
    patient_details, physician_details, radiology_orders = params.require %i[patient_details physician_details radiology_orders]
    radiology_orders = service.generate_msi(patient_details,physician_details, radiology_orders)
    render json: radiology_orders, status: :created
  end

  def service
    RadiologyService
  end
end
