# frozen_string_literal: true

require 'person_service'

class Api::V1::PeopleController < ApplicationController
  extend PersonService

  def index
    render json: Person.all
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

    person = create_person(create_params[:gender], create_params[:birth_date],
                           create_params[:birth_date_estimated])

    create_person_name(person, given_name: create_params[:given_name],
                               family_name: create_params[:family_name],
                               middle_name: create_params[:middle_name])

    create_person_attributes person, person_attributes(create_params)
    render json: person, status: :created
  end

  def update
  end

  def delete
  end

  private

  PERSON_FIELDS = %i[
    given_name middle_name family_name gender birth_date
    birth_date_estimated home_district home_village
    home_traditional_authority current_district current_village
    current_traditional_authority
  ].freeze

  PERSON_ATTRIBUTES = %i[
    home_district home_village home_traditional_authority
    current_district current_village current_traditional_authority
  ].freeze

  def person_attributes(_params)
    PERSON_ATTRIBUTES.each_with_object({}) do |fv_pair, attrs|
      attrs[fv_pair[0]] = fv_pair[1]
    end
  end
end
