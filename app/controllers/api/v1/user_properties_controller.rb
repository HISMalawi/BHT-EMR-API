class Api::V1::UserPropertiesController < ApplicationController
  include ModelUtils

  def search
    name, = params.require %i[property]

    render json: UserProperty.where('property like ?', "%#{name}%")
  end

  def show
    name, = params.require %i[property]

    user = User.current.user_id
    user = params[:user_id] if params.include?(:user_id)

    property = UserProperty.find_by property: name,
                                     user_id: user
    if property
      render json: property
    else
      render json: { errors: "Property, #{name} not found" }, status: :not_found
    end


  end

  def unique_property

    name,value = params.require %i[property property_value]
    property = UserProperty.where(property: name,property_value: value).exists?
    render json: property

  end


  def create(success_response_status: :created)
    name, value = params.require %i[property property_value]

    provider = User.current.user_id
    provider = params[:user_id] if params.include?(:user_id)

    property = UserProperty.find_by property: name,
                                     user_id: provider

    property ||= UserProperty.new property: name, user_id: provider
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
