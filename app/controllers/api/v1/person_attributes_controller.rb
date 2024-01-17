class Api::V1::PersonAttributesController < ApplicationController

  def index
    render json: get_values
  end

  def create
    permitted_params = params.permit(%i[person_attribute_type_id person_id value])
    attribute = PersonAttribute.create(permitted_params)
    if attribute.errors.empty?
      render json: attribute, status: :created
    else
      render json: attribute.errors, status: :bad_request
    end
  end

  def update
    attribute = PersonAttribute.find(params[:id])
    permitted_params = params.permit(%i[person_attribute_type_id value])

    if attribute.update(permitted_params)
      render json: attribute, status: :ok
    else
      render json: attribute.errors, status: :bad_request
    end
  end

  private

  def get_values
    person_id = params[:person_id]
    type_id = params[:person_attribute_type_id]

    return PersonAttribute.where(person_id: person_id,
      person_attribute_type_id: type_id).last
  end

end
