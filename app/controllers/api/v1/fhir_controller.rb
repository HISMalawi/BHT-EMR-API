# frozen_string_literal: true

module Api
  module V1
    class FhirController < ApplicationController
      skip_before_action :check_client_version, raise: false
      skip_before_action :check_location, raise: false
      skip_before_action :authenticate, raise: false
      before_action :set_fhir_user

      def set_fhir_user
        token = request.headers['Authorization'] || params[:auth_token]
        if token.present?
          user = UserService.authenticate(token) rescue nil
          User.current = user if user
        end
        User.current ||= User.first rescue nil
      end

      def metadata
        render json: FhirSerializer.capability_statement, content_type: 'application/fhir+json'
      end

      # GET /api/v1/fhir/Patient
      def patients
        if params[:id].present? || params[:_id].present?
          id = params[:id] || params[:_id]
          patient = Patient.find_by(patient_id: id)
          return render json: { error: 'Patient not found' }, status: :not_found unless patient

          render json: FhirSerializer.patient_to_fhir(patient), content_type: 'application/fhir+json'
        else
          scope = Patient.includes(person: :names)
          if params[:identifier].present?
            system, val = params[:identifier].split('|', 2)
            identifier_value = val.nil? ? system : val
            patient_ids = PatientIdentifier.where(identifier: identifier_value).pluck(:patient_id)
            scope = scope.where(patient_id: patient_ids)
          end
          if params[:name].present?
            person_ids = PersonName.where('given_name LIKE ? OR family_name LIKE ?', "%#{params[:name]}%", "%#{params[:name]}%").pluck(:person_id)
            scope = scope.where(patient_id: person_ids)
          end

          patients = scope.limit(params[:_count] || 50)
          fhir_patients = patients.map { |p| FhirSerializer.patient_to_fhir(p) }
          render json: FhirSerializer.bundle(fhir_patients), content_type: 'application/fhir+json'
        end
      end

      # GET /api/v1/fhir/Patient/:id
      def show_patient
        patient = Patient.find_by(patient_id: params[:id])
        return render json: { error: 'Patient not found' }, status: :not_found unless patient

        render json: FhirSerializer.patient_to_fhir(patient), content_type: 'application/fhir+json'
      end

      # GET /api/v1/fhir/ServiceRequest
      def service_requests
        if params[:id].present? || params[:_id].present?
          id = params[:id] || params[:_id]
          order = Order.find_by(order_id: id)
          return render json: { error: 'ServiceRequest not found' }, status: :not_found unless order

          render json: FhirSerializer.order_to_fhir_service_request(order), content_type: 'application/fhir+json'
        else
          scope = Order.includes(:concept, :patient, provider: :person)
          if params[:patient].present? || params[:subject].present?
            patient_ref = params[:patient] || params[:subject]
            patient_id = patient_ref.to_s.split('/').last
            scope = scope.where(patient_id: patient_id)
          end
          if params[:identifier].present?
            scope = scope.where(accession_number: params[:identifier])
          end

          orders = scope.limit(params[:_count] || 50)
          fhir_orders = orders.map { |o| FhirSerializer.order_to_fhir_service_request(o) }
          render json: FhirSerializer.bundle(fhir_orders), content_type: 'application/fhir+json'
        end
      end

      # GET /api/v1/fhir/ServiceRequest/:id
      def show_service_request
        order = Order.find_by(order_id: params[:id])
        return render json: { error: 'ServiceRequest not found' }, status: :not_found unless order

        render json: FhirSerializer.order_to_fhir_service_request(order), content_type: 'application/fhir+json'
      end

      # POST /api/v1/fhir/ServiceRequest
      def create_service_request
        resource = params[:resourceType] == 'ServiceRequest' ? params : params[:resource]
        unless resource
          return render json: { error: 'Invalid FHIR ServiceRequest resource' }, status: :bad_request
        end

        patient_ref = resource.dig(:subject, :reference) || ''
        patient_id = patient_ref.split('/').last
        patient = Patient.find_by(patient_id: patient_id) || Patient.first

        concept_id = resource.dig(:code, :coding, 0, :code) || Concept.first&.id
        accession_number = resource.dig(:identifier, 0, :value) || "ACC-#{Time.now.to_i}"

        encounter = Encounter.create!(
          patient_id: patient.id,
          encounter_type: EncounterType.first&.id || 1,
          program_id: Program.first&.id || 1,
          encounter_datetime: Time.now,
          provider_id: User.current&.person_id || Person.first&.id || 1,
          location_id: Location.current&.id || 1
        )

        order = Order.create!(
          patient_id: patient.id,
          encounter_id: encounter.id,
          concept_id: concept_id,
          order_type_id: OrderType.first&.id || 1,
          orderer: User.current&.id || 1,
          provider: User.current || User.first,
          start_date: Time.now,
          accession_number: accession_number
        )

        render json: FhirSerializer.order_to_fhir_service_request(order), status: :created, content_type: 'application/fhir+json'
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/fhir/Observation
      def observations
        if params[:id].present? || params[:_id].present?
          id = params[:id] || params[:_id]
          obs = Observation.find_by(obs_id: id)
          return render json: { error: 'Observation not found' }, status: :not_found unless obs

          render json: FhirSerializer.obs_to_fhir_observation(obs), content_type: 'application/fhir+json'
        else
          scope = Observation.includes(:concept)
          if params[:patient].present? || params[:subject].present?
            patient_ref = params[:patient] || params[:subject]
            patient_id = patient_ref.to_s.split('/').last
            scope = scope.where(person_id: patient_id)
          end
          if params[:order_id].present?
            scope = scope.where(order_id: params[:order_id])
          end

          obs_list = scope.limit(params[:_count] || 50)
          fhir_obs = obs_list.map { |o| FhirSerializer.obs_to_fhir_observation(o) }
          render json: FhirSerializer.bundle(fhir_obs), content_type: 'application/fhir+json'
        end
      end

      # GET /api/v1/fhir/Observation/:id
      def show_observation
        obs = Observation.find_by(obs_id: params[:id])
        return render json: { error: 'Observation not found' }, status: :not_found unless obs

        render json: FhirSerializer.obs_to_fhir_observation(obs), content_type: 'application/fhir+json'
      end

      # GET /api/v1/fhir/DiagnosticReport
      def diagnostic_reports
        if params[:id].present? || params[:_id].present?
          id = params[:id] || params[:_id]
          order = Order.find_by(order_id: id)
          return render json: { error: 'DiagnosticReport not found' }, status: :not_found unless order

          render json: FhirSerializer.order_to_fhir_diagnostic_report(order), content_type: 'application/fhir+json'
        else
          scope = Order.includes(:concept, :observations)
          if params[:patient].present? || params[:subject].present?
            patient_ref = params[:patient] || params[:subject]
            patient_id = patient_ref.to_s.split('/').last
            scope = scope.where(patient_id: patient_id)
          end

          orders = scope.limit(params[:_count] || 50)
          fhir_reports = orders.map { |o| FhirSerializer.order_to_fhir_diagnostic_report(o) }
          render json: FhirSerializer.bundle(fhir_reports), content_type: 'application/fhir+json'
        end
      end

      # GET /api/v1/fhir/DiagnosticReport/:id
      def show_diagnostic_report
        order = Order.find_by(order_id: params[:id])
        return render json: { error: 'DiagnosticReport not found' }, status: :not_found unless order

        render json: FhirSerializer.order_to_fhir_diagnostic_report(order), content_type: 'application/fhir+json'
      end

      # POST /api/v1/fhir/send_order_to_lab
      def send_order_to_lab
        order = Order.find(params.require(:order_id))
        result = FhirLabClient.send_order_to_lab(
          order,
          lab_fhir_url: params[:lab_fhir_url],
          auth_token: params[:auth_token]
        )
        render json: result
      end

      # GET /api/v1/fhir/fetch_results_from_lab
      def fetch_results_from_lab
        accession_number = params.require(:accession_number)
        result = FhirLabClient.fetch_results_from_lab(
          accession_number,
          lab_fhir_url: params[:lab_fhir_url],
          auth_token: params[:auth_token]
        )
        render json: result
      end
    end
  end
end
