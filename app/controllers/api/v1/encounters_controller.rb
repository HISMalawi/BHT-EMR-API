require 'utils/remappable_hash'

class Api::V1::EncountersController < ApplicationController
  # TODO: Move pretty much all CRUD ops in this module to EncounterService

  # Retrieve a list of encounters
  #
  # GET /encounter
  #
  # Optional parameters:
  #   patient_id: Retrieve encounters belonging to this patient
  #   location_id: Retrieve encounters at this location
  #   encounter_type_id: Retrieve encounters with this id only
  #   page, page_size: For pagination. Defaults to page 0 of size 12
  def index
    # Ignoring error value as required_params never errors when
    # retrieving optional parameters only
    filters = params.permit(%i[patient_id location_id encounter_type_id date program_id])

    if filters.empty?
      queryset = Encounter.all
    else
      remap_encounter_type_id! filters if filters[:encounter_type_id]
      date = filters.delete(:date)
      queryset = Encounter.where(filters)
      if date
        queryset = queryset.where('encounter_datetime BETWEEN DATE(?) AND (DATE(?) + INTERVAL 1 DAY)', date, date)
      end
    end

    queryset = queryset.includes(%i[type patient location provider program], observations: { concept: %i[concept_names] })
                       .order(:date_created)

    render json: paginate(queryset)
  end

  # Generate a report on counts of various encounters
  #
  # POST /reports/encounters
  #
  # Optional parameters:
  #    all - Retrieves all encounters not just those created by current user
  def count
    encounter_types, = params.require(%i[encounter_types])

    complete_report = encounter_types.each_with_object({}) do |type_id, report|
      male_count = count_by_gender(type_id, 'M', params[:date])
      fem_count = count_by_gender(type_id, 'F', params[:date])
      report[type_id] = { 'M': male_count, 'F': fem_count }
    end

    render json: complete_report
  end

  # Retrieve single encounter.
  #
  # GET /encounter/:id
  def show
    render json: Encounter.find(params[:id])
  end

  # Create a new Encounter
  #
  # POST /encounter
  #
  # Required parameters:
  #   encounter_type_id: Encounter's type
  #   patient_id: Patient involved in the encounter
  #
  # Optional parameters:
  #   provider_id: user_id of surrogate doing the data entry defaults to current user
  def create
    type_id, patient_id, program_id = params.require(%i[encounter_type_id patient_id program_id])

    encounter = encounter_service.create(
      type: EncounterType.find(type_id),
      patient: Patient.find(patient_id),
      program: Program.find(program_id),
      provider: params[:provider_id] ? Person.find(params[:provider_id]) : User.current.person,
      encounter_datetime: TimeUtils.retro_timestamp(params[:encounter_datetime]&.to_time || Time.now),
      program: Program.find(program_id)

    )

    if encounter.errors.empty?
      render json: encounter, status: :created
    else
      render json: encounter.errors, status: :bad_request
    end
  end

  # Update an existing encounter
  #
  # PUT /encounter/:id
  #
  # Optional parameters:
  #   encounter_type_id: Encounter's type
  #   patient_id: Patient involved in the encounter
  def update
    encounter = Encounter.find(params[:id])
    type = params[:type_id] && EncounterType.find(params[:type_id])
    patient = params[:patient_id] && Patient.find(params[:patient_id])
    provider = params[:provider_id] ? Person.find(params[:provider_id]) : User.current.person
    encounter_datetime = TimeUtils.retro_timestamp(params[:encounter_datetime]&.to_time || Time.now)

    encounter_service.update(encounter, type: type, patient: patient,
                                        provider: provider,
                                        encounter_datetime: encounter_datetime)
  end

  # Void an existing encounter
  #
  # DELETE /encounter/:id
  def destroy
    encounter = Encounter.find(params[:id])
    reason = params[:reason] || "Voided by #{User.current.username}"
    encounter_service.void encounter, reason
  end

  private

  # HACK: Have to rename encounter_type_id because in the model
  # underneath it is unfortunately named encounter_type not
  # encounter_type_id. However, we prefer to use encounter_type_id
  # when receiving input from clients to retain an orthogonal
  # interface across the API. Can't be using person_id, patient_id,
  # etc and then surprise our clients with encounter_type as another
  # form of an id.
  def remap_encounter_type_id!(hash)
    hash.remap_field! :encounter_type_id, :encounter_type
  end

  def count_by_gender(type_id, gender, date = nil)
    filters = { encounter_type: type_id }
    filters[:creator] = User.current.user_id unless params[:all]

    queryset = Encounter.where(filters)
    queryset = queryset.joins(
      'INNER JOIN person ON encounter.patient_id = person.person_id'
    ).where('person.gender = ?', gender)
    if params[:date]
      date = Date.strptime params[:date]
      queryset = queryset.where '(encounter_datetime BETWEEN (?) AND (?))',
        date.strftime('%Y-%m-%d 00:00:00'), date.strftime('%Y-%m-%d 23:59:59')
    end

    queryset.count
  end

  def encounter_service
    EncounterService.new
  end
end
