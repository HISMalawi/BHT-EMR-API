class Api::V1::PersonAttributesController < ApplicationController

  def index
    render json: get_values
  end


  private

  def get_values
    person_id = params[:person_id]
    type_id = params[:person_attribute_type_id]

    return PersonAttribute.where(person_id: person_id, 
      person_attribute_type_id: type_id).last
  end

end
