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

    person = create_person(create_params)
    create_person_name(person, create_params)
    create_person_address(person, create_params)

    # create_person_attributes person, person_attributes(create_params)
    render json: person, status: :created
  end

  def update
    update_params, errors = required_params optional: PERSON_FIELDS
    return render json: { errors: errors }, status: :bad_request if errors

    person = People.find(params[:id])

    update_person person, update_params
    update_person_name person, update_params
    update_person_address person, update_params

    # TODO: Send person to DDE service in a fire and forget fashion

    render json: person, status: :created
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
