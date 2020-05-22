# frozen_string_literal: true

class Api::V1::PeopleController < ApplicationController
  def index
    render json: paginate(Person)
  end

  # Search for patients by name and gender
  #
  # GET /search/people?given_name={value}&family_name={value}&gender={value}
  #
  # @{deprecated} - See GET /search/patients
  def search
    filters = params.permit(%i[given_name middle_name family_name gender])

    people = person_service.find_people_by_name_and_gender(filters[:given_name],
                                                           filters[:middle_name],
                                                           filters[:family_name],
                                                           filters[:gender])
    render json: paginate(people).sort_by(&:name)
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

    render json: person, status: :created
  end

  def update
    person = Person.find(params[:id])
    program = Program.find_by_program_id(params[:program_id])
    update_params = params.permit!

    person_service.update_person(person, update_params)
    person_service.update_person_name(person, update_params)
    person_service.update_person_address(person, update_params)
    person_service.update_person_attributes(person, update_params)

    person.reload

    # Hack trigger a patient update to force a DDE push if DDE is active
    patient_service.update_patient(program, person.patient) if person.patient

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

  def list
    clients  = ActiveRecord::Base.connection.select_all <<~SQL
    SELECT p.*, a.identifier FROM person p
    LEFT JOIN patient_identifier a ON a.patient_id = p.person_id
    AND a.identifier_type = 4 AND a.voided = 0
    WHERE p.person_id IN(#{params[:person_ids]})
    GROUP BY p.person_id ORDER BY a.date_created DESC;
    SQL

    render json: clients
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
