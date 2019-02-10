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

    people = person_service.find_people_by_gender_and_name(given_name, family_name, gender)
    render json: paginate(people)
  end

  def show
    render json: Person.find(params[:id])
  end

  def create
    create_params, errors = required_params required: PersonService::PERSON_FIELDS,
                                            optional: [:middle_name]
    return render json: create_params, status: :bad_request if errors

    person = person_service.create_person(create_params)
    person_service.create_person_name(person, create_params)
    person_service.create_person_address(person, create_params)
    person_service.create_person_attributes(person, params.permit!)

    # Hack trigger a patient update to force a DDE push if DDE is active
    patient_service.update_patient(person.patient) if person.patient

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

    person.reload

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

  def patient_service
    PatientService.new
  end
end
