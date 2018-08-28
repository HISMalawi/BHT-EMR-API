# frozen_string_literal: true

require 'person_service'

class Api::V1::PeopleController < ApplicationController
  include PersonService

  def index
    # TODO: Add pagination
    render json: Person.all.limit(10)
  end

  def show
    person = Person.find(params[:id])
    unless person
      errors = ["Person ##{params[:id]} not found"]
      render json: { errors: errors }, status: :not_found
      return
    end
    render json: person
  end

  def create
    create_params, errors = required_params required: PERSON_FIELDS
    return render json: create_params, status: :bad_request if errors

    person = create_person(create_params[:gender], create_params[:birthdate],
                           create_params[:birthdate_estimated])

    create_person_name(person, given_name: create_params[:given_name],
                               family_name: create_params[:family_name],
                               middle_name: create_params[:middle_name])

    create_person_attributes person, person_attributes(create_params)
    render json: person, status: :created
  end

  def update
  end

  def destroy
    person = Person.find(params[:id])
    if person.void
      render status: :no_content
    else
      render json: { errors: "Failed to void person ##{person_id}" }
    end
  end

  private

  PERSON_FIELDS = %i[
    given_name middle_name family_name gender birthdate
    birthdate_estimated home_district home_village
    home_traditional_authority current_district current_village
    current_traditional_authority
  ].freeze

  PERSON_ATTRIBUTES = %i[
    home_district home_village home_traditional_authority
    current_district current_village current_traditional_authority
  ].freeze

  def person_attributes(_params)
    PERSON_ATTRIBUTES.each_with_object({}) do |field, attrs|
      attrs[field] = params[field]
    end
  end
end
