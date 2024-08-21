# frozen_string_literal: true

module Api
  module V1
    class PeopleController < ApplicationController
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
        people = people.includes(%i[names addresses], person_attributes: %i[type])

        render json: paginate(people).sort_by(&:name)
      end

      def show
        render json: Person.find(params[:id])
      end

      def valid_provider_id
        # get json of provider_ids
        provider_id = params[:provider_id]
        ids_json = JSON.parse(File.read("#{Rails.root}/db/hts_metadata/provider_ids.json"))
        render json: ids_json.map { |q| q['htc_prov_id']&.downcase }.include?(provider_id&.downcase)
      end

      def next_hts_linkage_ids_batch
        ActiveRecord::Base.transaction do
          max_id_property = GlobalProperty.find_or_create_by(property: 'hts.max_linkage_code_batch')
          threshold_property = GlobalProperty.find_or_create_by(property: 'hts.linkage_code_batch_threshold')
          max_id_value = max_id_property&.property_value.to_i
          threshold = threshold_property&.property_value&.to_i || 1000
          max_id_property.update(property_value: max_id_value + threshold)
          render json: { min_id: max_id_value + 1, max_id: max_id_value + threshold }
        end
      end

      def create
        create_params, errors = required_params required: PersonService::PERSON_FIELDS,
                                                optional: [:middle_name]
        return render json: create_params, status: :bad_request if errors
        return unless validate_birthdate params['birthdate']

        person = Person.transaction do
          person = person_service.create_person(create_params)
          person_service.create_person_name(person, create_params)
          person_service.create_person_address(person, create_params)
          person_service.create_person_attributes(person, params.permit!)

          person
        end

        render json: person, status: :created
      end

      def update
        program_id = params.require(:program_id) if DdeService.dde_enabled?
        person = Person.find(params[:id])
        update_params = params.permit!

        person_service.update_person(person, update_params)
        person.reload

        # Hack trigger a patient update to force a DDE push if DDE is active
        patient_service.update_patient(Program.find(program_id), person.patient) if program_id && person.patient

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
        clients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT p.*, a.identifier, patient_start_date(p.person_id) AS art_start_date
          FROM person p
          LEFT JOIN patient_identifier a ON a.patient_id = p.person_id AND a.identifier_type = 4 AND a.voided = 0
          WHERE p.person_id IN(#{params[:person_ids]})
          GROUP BY p.person_id ORDER BY a.date_created DESC;
        SQL

        render json: clients
      end

      def tb_list
        clients = ActiveRecord::Base.connection.select_all <<~SQL
          SELECT p.person_id, 
                 CONCAT(pn.given_name, ' ', pn.family_name) AS name,
                 p.gender, TIMESTAMPDIFF(YEAR, p.birthdate, CURDATE()) AS age,
                 a.identifier 
          FROM person p
          INNER JOIN person_name pn ON pn.person_id = p.person_id
          LEFT JOIN patient_identifier a ON a.patient_id = p.person_id
          AND a.identifier_type IN (7, 11) AND a.voided = 0
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

      def validate_birthdate(birthdate)
        if birthdate.nil?
          render json: ['birthdate cannot be empty'], status: :bad_request
          return false
        end

        true
      end

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
  end
end
