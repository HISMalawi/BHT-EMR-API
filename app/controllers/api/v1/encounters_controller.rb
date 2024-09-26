# frozen_string_literal: true

require 'utils/remappable_hash'

module Api
  module V1
    class EncountersController < ApplicationController
 

      after_action :immunization_cache_update, only: [:destroy]
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
            queryset = queryset.where('encounter_datetime BETWEEN DATE(?) AND (DATE(?) + INTERVAL 1 DAY)', date,
                                      date)
          end
        end

        queryset = queryset.includes(%i[type patient location program], provider: [:names],
                                                                        observations: { concept: %i[concept_names] })
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
          male_count = count_by_gender(type_id, 'M', params[:program_id].to_i, params[:date])
          fem_count = count_by_gender(type_id, 'F', params[:program_id].to_i, params[:date])
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
          encounter_datetime: TimeUtils.retro_timestamp(params[:encounter_datetime]&.to_time || Time.now)
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

        encounter_service.update(encounter, type:, patient:,
                                            provider:,
                                            encounter_datetime:)
      end

   
      def daily_visits   
          # Get the queryset by calling the helper method
        queryset = fetch_daily_visits_query
      
          # Render the queryset as JSON
        render json: paginate(queryset)
      end
      
        # Separate endpoint to generate visit numbers
      def generate_visit_number
          # Get the queryset by calling the helper method
        queryset = fetch_daily_visits_query
      
          # Generate visit numbers based on the queryset
        visit_numbers = generate_visit_numbers(queryset)
      
          # Render the visit numbers as JSON
        render json: { visit_numbers: visit_numbers }
      end
      
      private
      
        # Refactored method to fetch the queryset for daily visits
      def fetch_daily_visits_query
        filters = params.permit(%i[patient_id location_id encounter_type_id date program_id])
          
        if filters.empty?
          queryset = Encounter.all
        else
          remap_encounter_type_id!(filters) if filters[:encounter_type_id]
          date = filters.delete(:date)
          queryset = Encounter.where(filters)
      
            # Filter by the date range if provided
          if date
            queryset = queryset.where('encounter_datetime BETWEEN DATE(?) AND (DATE(?) + INTERVAL 1 DAY)', date, date)
          end
        end
      
          # Apply the condition for program_id = 14 and encounter_type.name = 'REGISTRATION'
        queryset = queryset.joins(:type)
                            .where(program_id: 14, type: { name: 'REGISTRATION' })
      
        queryset = queryset.includes(%i[type patient location program], provider: [:names],
                                                                observations: { concept: %i[concept_names] })
                            .order(:date_created)
      
        queryset
      end
      
        # Generate visit numbers for the queryset
      def generate_visit_numbers(queryset)
        visit_numbers = {}
        queryset.each_with_index do |encounter, index|
            # Generate visit number logic
          visit_numbers[encounter.id] = "VISIT-#{encounter.id}-#{index + 1}"
        end
        visit_numbers
      end
    
      
      

      #def daily_visits   
        # Ignoring error value as required_params never errors when
        # retrieving optional parameters only
      #  filters = params.permit(%i[patient_id location_id encounter_type_id date program_id])
      
      #  if filters.empty?
      #    queryset = Encounter.all
      #  else
      #    remap_encounter_type_id!(filters) if filters[:encounter_type_id]
      #    date = filters.delete(:date)
      #    queryset = Encounter.where(filters)
      
          # Filter by the date range if provided
      #    if date
      #      queryset = queryset.where('encounter_datetime BETWEEN DATE(?) AND (DATE(?) + INTERVAL 1 DAY)', date, date)
      #    end
      #  end
      
        # Apply the condition for program_id = 14 and encounter_type.name = 'REGISTRATION'
      #  queryset = queryset.joins(:type)
      #                     .where(program_id: 14, type: { name: 'REGISTRATION' })
      
      #  queryset = queryset.includes(%i[type patient location program], provider: [:names],
      #                                                              observations: { concept: %i[concept_names] })
      #                     .order(:date_created)
      
      #  render json: paginate(queryset)
     # end
      
    
      #def generate_visit_number

  
      #  taken_visit_ids = Observation.joins(:encounter)
      #     .where(
      #       concept_id: ConceptName.find_by_name('OPD Visit number').concept_id
      #     )
      #     .select('obs.value_numeric')

      #  visit_number = 1
      #  visit_number += 1 while taken_visit_ids.include?(visit_number) && not_assigned_today?(visit_number)

      #  render json: { next_visit_number: visit_number }, status: :ok
      #end      

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

      def count_by_gender(type_id, gender, program_id, date = nil)
        filters = { encounter_type: type_id, program_id: }
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


      def immunization_cache_update
        # Update Immunization Data Cache
        start_date = 1.year.ago.to_date.to_s
        end_date = Date.today.to_s
        
        location_id = User.current.location_id

        ImmunizationReportJob.perform_later(start_date, end_date, location_id)  
        DashboardStatsJob.perform_later(location_id)
      end

    end
  end
end
