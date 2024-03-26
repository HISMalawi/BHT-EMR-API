# frozen_string_literal: true

module Api
  module V1
    class LabTestOrdersController < ApplicationController
      include LabTestsEngineLoader

      def index
        if params[:accession_number]
          orders = engine.find_orders_by_accession_number params[:accession_number]
          render json: orders
        elsif params[:patient_id]
          patient = Patient.find params[:patient_id]
          orders = engine.find_orders_by_patient patient
          # NOTE: orders can't be paginated here as it is just an ordinary array
          # not a queryset
          render json: orders
        else
          render json: { errors: ['accession_number or patient_id required'] },
                 status: :bad_request
        end
      end

      def create
        tests, encounter_id, requesting_clinician = params.require %i[
          tests encounter_id requesting_clinician
        ]

        begin
          date = TimeUtils.retro_timestamp(params[:date]&.to_time || Time.now)
        rescue ArgumentError => e
          error = "Failed to parse date(#{params[:date]}): #{e}"
          return render json: { errors: [error] }, status: :bad_request
        end

        encounter = Encounter.find encounter_id

        order = engine.create_order(tests:,
                                    encounter:,
                                    date:,
                                    requesting_clinician:)

        render json: order, status: :created
      end

      def create_external_order
        patient_id, accession_number = params.require(%i[patient_id accession_number])
        date = params[:date]&.to_date || Date.today
        patient = Patient.find(patient_id)

        render json: engine.create_external_order(patient, accession_number, date)
      end

      def create_legacy_order
        specimen_type, test_type, reason = params.require(%i[specimen_type test_type reason])
        date = params[:date]&.to_date || Date.today

        order = engine.create_legacy_order(patient, 'test_name' => test_type,
                                                    'sample_type' => specimen_type,
                                                    'reason_for_test' => reason,
                                                    'sample_status' => 'specimen_collected',
                                                    'date_sample_drawn' => date)

        render json: order, status: :created
      end

      def locations
        search_name = params[:search_name]

        locations_list = engine.lab_locations
        locations_list = locations_list.select { |location| location.include?(search_name) } if search_name

        render json: locations_list
      end

      def labs
        search_name = params[:search_name]

        labs_list = engine.labs
        labs_list = labs_list.select { |labs| labs.include?(search_name) } if search_name

        render json: labs_list
      end

      def orders_without_results
        render json: engine.orders_without_results(patient)
      end

      private

      def patient
        Patient.find(params[:patient_id])
      end
    end
  end
end
