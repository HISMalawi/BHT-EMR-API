# frozen_string_literal: true

module Lab
  ##
  # Manage lab orders.
  #
  # Lab orders are just ordinary openmrs orders with extra metadata that
  # separates them from other orders. Lab orders have an order type of 'Lab'
  # with the order's test type as the order's concept. The order's start
  # date is the day the order is made. Additional information pertaining to
  # the order is stored as observations that point to the order. The
  # specimen types, requesting clinician, target lab, and reason for test
  # are saved as observations to the order. Refer to method #order_test for
  # more information.
  module OrdersService
    class << self
      ##
      # Create a lab order.
      #
      # Parameters schema:
      #
      #     {
      #       encounter_id: {
      #         type: :integer,
      #         required: :false,
      #         description: 'Attach order to this if program_id and patient_id are not provided'
      #       },
      #       program_id: { type: :integer, required: false },
      #       patient_id: { type: :integer, required: false }
      #       specimen: { type: :object, properties: { concept_id: :integer }, required: %i[concept_id] },
      #       test_type_ids: {
      #         type: :array,
      #         items: {
      #           type: :object,
      #           properties: { concept_id: :integer },
      #           required: %i[concept_id]
      #         }
      #       },
      #       start_date: { type: :datetime }
      #       accession_number: { type: :string }
      #       target_lab: { type: :string },
      #       reason_for_test_id: { type: :integer },
      #       requesting_clinician: { type: :string }
      #     }
      #
      # encounter_id: is an ID of the encounter the lab order is to be created under
      # test_type_id: is a concept_id of the name of test being ordered
      # specimen_type_id: is a list of IDs for the specimens to be tested (can be ommited)
      # target_lab: is the name of the lab where test will be carried out
      # reason_for_test_id: is a concept_id for a (standard) reason of why the test is being carried out
      # requesting_clinician: Name of the clinician requesting the test (defaults to current user)
      def order_test(order_params)
        Order.transaction do
          encounter = find_encounter(order_params)
          if order_params[:accession_number].present? && check_tracking_number(order_params[:accession_number])
            raise 'Accession number already exists'
          end

          order = create_order(encounter, order_params)

          Lab::TestsService.create_tests(order, order_params[:date], order_params[:tests])

          Lab::LabOrderSerializer.serialize_order(
            order, requesting_clinician: add_requesting_clinician(order, order_params),
                   reason_for_test: add_reason_for_test(order, order_params),
                   target_lab: add_target_lab(order, order_params)
          )
        end
      end

      def update_order(order_id, params)
        specimen_id = params.dig(:specimen, :concept_id)
        raise ::InvalidParameterError, 'Specimen concept_id is required' unless specimen_id

        order = Lab::LabOrder.find(order_id)
        if order.concept_id != unknown_concept_id && !params[:force_update]&.casecmp?('true')
          raise ::UnprocessableEntityError, "Can't change order specimen once set"
        end

        if specimen_id.to_i != order.concept_id
          Rails.logger.debug("Updating order ##{order.order_id}")
          order.update!(concept_id: specimen_id,
                        discontinued: true,
                        discontinued_by: User.current.user_id,
                        discontinued_date: params[:date]&.to_date || Time.now,
                        discontinued_reason_non_coded: 'Sample drawn/updated')
        end

        if params[:reason_for_test_id]
          Rails.logger.debug("Updating reason for test on order ##{order.order_id}")
          update_reason_for_test(order, params[:reason_for_test_id])
        end

        Lab::LabOrderSerializer.serialize_order(order)
      end

      def void_order(order_id, reason)
        order = Lab::LabOrder.includes(%i[requesting_clinician reason_for_test target_lab], tests: [:result])
                             .find(order_id)

        order.requesting_clinician&.void(reason)
        order.reason_for_test&.void(reason)
        order.target_lab&.void(reason)

        order.tests.each { |test| test.void(reason) }
        order.void(reason)
      end

      def check_tracking_number(tracking_number)
        accession_number_exists?(tracking_number) || nlims_accession_number_exists?(tracking_number)
      end

      def update_order_status(order_params)
        # find the order
        order = find_order(order_params['tracking_number'])
        concept = ConceptName.find_by_name Lab::Metadata::LAB_ORDER_STATUS_CONCEPT_NAME
        ActiveRecord::Base.transaction do
          void_order_status(order, concept)
          Observation.create!(
            person_id: order.patient_id,
            encounter_id: order.encounter_id,
            concept_id: concept.concept_id,
            order_id: order.id,
            obs_datetime: order_params['status_time'] || Time.now,
            value_text: order_params['status'],
            creator: User.current.id
          )
        end
        create_rejection_notification(order_params) if order_params['status'] == 'test-rejected'
      end

      def update_order_result(order_params)
        order = find_order(order_params['tracking_number'])
        order_dto = Lab::Lims::OrderSerializer.serialize_order(order)
        patch_order_dto_with_lims_results!(order_dto, order_params['results'])
        Lab::Lims::PullWorker.new(nil).process_order(order_dto)
      end

      private

      def create_rejection_notification(order_params)
        order = find_order order_params['tracking_number']
        data = { 'type': 'LIMS',
                 'accession_number': order&.accession_number,
                 'order_date': order&.start_date,
                 'arv_number': find_arv_number(order.patient_id),
                 'patient_id': result.person_id,
                 'ordered_by': order&.provider&.person&.name,
                 'rejection_reason': order_params['comments']
                }.as_json
        NotificationService.new.create_notification('LIMS', data)
      end

      def find_arv_number(patient_id)
        PatientIdentifier.joins(:type)
                         .merge(PatientIdentifierType.where(name: 'ARV Number'))
                         .where(patient_id: patient_id)
                         .first&.identifier
      end

      def find_order(tracking_number)
        Lab::LabOrder.find_by_accession_number(tracking_number)
      end

      def patch_order_dto_with_lims_results!(order_dto, results)
        order_dto.merge!(
          '_id' => order_dto[:tracking_number],
          '_rev' => 0,
          'test_results' => results.each_with_object({}) do |result, formatted_results|
            test_name, measures = result
            result_date = measures.delete('result_date')

            formatted_results[test_name] = {
              results: measures.each_with_object({}) do |measure, processed_measures|
                processed_measures[measure[0]] = { 'result_value' => measure[1] }
              end,
              result_date: result_date,
              result_entered_by: {}
            }
          end
        )
      end

      ##
      # Extract an encounter from the given parameters.
      #
      # Uses an encounter_id to retrieve an encounter if provided else
      # a 'Lab' encounter is created using the provided program_id and
      # patient_id.
      def find_encounter(order_params)
        return Encounter.find(order_params[:encounter_id]) if order_params[:encounter_id]

        raise InvalidParameterError, 'encounter_id or patient_id required' unless order_params[:patient_id]

        program_id = order_params[:program_id] || Program.find_by_name!(Lab::Metadata::LAB_PROGRAM_NAME).program_id

        Encounter.create!(
          patient_id: order_params[:patient_id],
          program_id:,
          type: EncounterType.find_by_name!(Lab::Metadata::ENCOUNTER_TYPE_NAME),
          encounter_datetime: order_params[:date] || Date.today,
          provider_id: order_params[:provider_id] || User.current.person.person_id
        )
      end

      def create_order(encounter, params)
        access_number = params[:accession_number] || next_accession_number(params[:date]&.to_date || Date.today)
        raise 'Accession Number cannot be blank' unless access_number.present?
        raise 'Accession cannot be this short' unless access_number.length > 6
        Lab::LabOrder.create!(
          order_type: OrderType.find_by_name!(Lab::Metadata::ORDER_TYPE_NAME),
          concept_id: params.dig(:specimen, :concept_id) || unknown_concept_id,
          encounter_id: encounter.encounter_id,
          patient_id: encounter.patient_id,
          start_date: params[:date]&.to_date || Date.today,
          auto_expire_date: params[:end_date],
          accession_number: access_number,
          orderer: User.current&.user_id
        )
      end

      def accession_number_exists?(accession_number)
        Lab::LabOrder.where(accession_number:).exists?
      end

      def nlims_accession_number_exists?(accession_number)
        config = YAML.load_file('config/application.yml')
        return false unless config['lims_api']

        # fetch from the rest api and check if it exists
        lims_api = Lab::Lims::ApiFactory.create_api
        lims_api.verify_tracking_number(accession_number).present?
      end

      ##
      # Attach the requesting clinician to an order
      def add_requesting_clinician(order, params)
        create_order_observation(
          order,
          Lab::Metadata::REQUESTING_CLINICIAN_CONCEPT_NAME,
          params[:date],
          value_text: params['requesting_clinician']
        )
      end

      ##
      # Attach a reason for the order/test
      #
      # Examples of reasons include: Routine, Targeted, Confirmatory, Repeat, or Stat.
      def add_reason_for_test(order, params)
        create_order_observation(
          order,
          Lab::Metadata::REASON_FOR_TEST_CONCEPT_NAME,
          params[:date],
          value_coded: params[:reason_for_test_id]
        )
      end

      ##
      # Attach the lab where the test is going to get carried out.
      def add_target_lab(order, params)
        return nil unless params['target_lab']

        create_order_observation(
          order,
          Lab::Metadata::TARGET_LAB_CONCEPT_NAME,
          params[:date],
          value_text: params['target_lab']
        )
      end

      def create_order_observation(order, concept_name, date, **)
        Observation.create!(
          order:,
          encounter_id: order.encounter_id,
          person_id: order.patient_id,
          concept_id: ConceptName.find_by_name!(concept_name).concept_id,
          obs_datetime: date&.to_time || Time.now,
          **
        )
      end

      def next_accession_number(date = nil)
        Lab::AccessionNumberService.next_accession_number(date)
      end

      def unknown_concept_id
        ConceptName.find_by_name!('Unknown').concept_id
      end

      def update_reason_for_test(order, concept_id)
        raise InvalidParameterError, "Reason for test can't be blank" if concept_id.blank?

        return if order.reason_for_test&.value_coded == concept_id

        raise InvalidParameterError, "Can't change reason for test once set" if order.reason_for_test&.value_coded

        order.reason_for_test&.delete
        add_reason_for_test(order, date: order.start_date, reason_for_test_id: concept_id)
      end

      def void_order_status(order, concept)
        Observation.where(order_id: order.id, concept_id: concept.concept_id).each do |obs|
          obs.void('New Status Received from LIMS')
        end
      end
    end
  end
end
