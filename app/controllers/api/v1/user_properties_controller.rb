class Api::V1::UserPropertiesController < ApplicationController
  include ModelUtils

  def search
    name, = params.require %i[property]

    render json: UserProperty.where('property like ?', "%#{name}%")
  end

  def show
    name, = params.require %i[property]
    property = UserProperty.find_by property: name,
                                    user_id: User.current.user_id
    if property
      render json: property
    else
      render json: { errors: "Property, #{name} not found" }, status: :not_found
    end
  end

  def create(success_response_status: :created)
    name, value = params.require %i[property property_value]

    property = user_property name
    property ||= UserProperty.new property: name, user_id: User.current.user_id
    property.property_value = value

    if property.save
      render json: property, status: success_response_status
    else
      render json: ['Failed to save property'], status: :internal_server_error
    end
  end

  def update
    create success_response_status: :ok
  end

  def destroy
    name = params.require %i[property]
    property = UserProperty.find_by name: name, user_id: User.current.user_id
    if property.nil?
      render json: { errors: ["Property, #{name}, not found"] }
    elsif property.destroy
      render status: :no_content
    else
      render json: { errors: property.errors }, status: :internal_server_error
    end
  end
end
