# frozen_string_literal: true

class Api::V1::PeopleController < ApplicationController
  def index
    render json: paginate(Person)
  end

  # Search for patients by name and gender
  #
  # GET /search/people?given_name={value}&family_name={value}&gender={value}
  def search
    given_name, family_name, gender = params.require %i[given_name family_name gender]

    people = paginate(Person.joins(:names).where(
      'person.gender like ? AND person_name.given_name LIKE ?
                            AND person_name.family_name LIKE ?',
      "#{gender}%", "#{given_name}%", "#{family_name}%"
    ))
    render json: people
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
    create_params, errors = required_params required: person_service::PERSON_FIELDS,
                                            optional: [:middle_name]
    return render json: create_params, status: :bad_request if errors

    person = person_service.create_person create_params
    person_service.create_person_name person, create_params
    person_service.create_person_address person, create_params
    person_service.create_person_attributes person, params.permit!

    render json: person, status: :created
  end

  def update
    person = Person.find(params[:id])
    update_params = params.permit!

    person_service.update_person person, update_params
    person_service.update_person_name person, update_params
    person_service.update_person_address person, update_params
    person_service.update_person_attributes person, update_params

    # ASIDE: Person we just updated may be linked to DDE, if this is the
    # case, do we notify DDE of the update right now or do we force client
    # to trigger an update in DDE by calling POST /patient/:patient_id?

    render json: person, status: :ok
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

  def person_service
    PersonService.new
  end
end
