# frozen_string_literal: true

module Lab
  module Lims
    ##
    # LIMS' Data Transfer Object for orders
    class OrderDTO < ActiveSupport::HashWithIndifferentAccess
      class << self
        include Utils

        ##
        # Takes a Lab::LabOrder and serializes it into a DTO
        def from_order(order)
          serialized_order = structify(Lab::LabOrderSerializer.serialize_order(order))

          new(
            tracking_number: serialized_order.accession_number,
            sending_facility: current_facility_name,
            receiving_facility: serialized_order.target_lab,
            tests: serialized_order.tests.collect(&:name),
            patient: format_patient(serialized_order.patient_id),
            order_location: format_order_location(serialized_order.encounter_id),
            sample_type: format_sample_type(serialized_order.specimen.name),
            sample_status: format_sample_status(serialized_order.specimen.name),
            districy: current_district, # yes districy [sic]...
            priority: serialized_order.reason_for_test.name,
            date_created: serialized_order.order_date,
            test_results: format_test_results(serialized_order),
            type: 'Order'
          )
        end

        private

        def format_order_location(encounter_id)
          location_id = Encounter.select(:location_id).where(encounter_id: encounter_id)
          location = Location.select(:name)
                             .where(location_id: location_id)
                             .first

          location&.name
        end

        # Format patient into a structure that LIMS expects
        def format_patient(patient_id)
          person = Person.find(patient_id)
          name = PersonName.find_by_person_id(patient_id)
          national_id = PatientIdentifier.joins(:type)
                                         .merge(PatientIdentifierType.where(name: 'National ID'))
                                         .where(patient_id: patient_id)
                                         .first
          phone_number = PersonAttribute.joins(:type)
                                        .merge(PersonAttributeType.where(name: 'Cell phone Number'))
                                        .where(person_id: patient_id)
                                        .first

          {
            first_name: name&.given_name,
            last_name: name&.family_name,
            id: national_id&.value,
            phone_number: phone_number,
            gender: person.gender,
            email: nil
          }
        end

        def format_sample_type(name)
          name.casecmp?('Unknown') ? 'not_specified' : name
        end

        def format_sample_status(name)
          name.casecmp?('Unknown') ? 'specimen_not_collected' : 'specimen_collected'
        end

        def format_test_results(order)
          order.tests.each_with_object({}) do |test, results|
            results[test.name] = {
              results: test.result.each_with_object({}) do |measure, measures|
                measures[measure.indicator.name] = { result_value: "#{measure.value_modifier}#{measure.value}" }
              end,
              result_date: test.result.first&.date,
              result_entered_by: {}
            }
          end
        end

        def current_health_center
          health_center = Location.current_health_center
          raise 'Current health center not set' unless health_center

          health_center
        end

        def current_district
          unless current_health_center.parent
            raise "Current health center ##{current_health_center.id} is not associated with any district"
          end

          current_health_center.city_village || current_health_center.parent.name
        end

        def current_facility_name
          current_health_center.name
        end
      end

      ##
      # Unpacks a LIMS order into an object that OrdersService can handle
      def to_order_service_params(lims_order)
        ActiveSupport::HashWithIndifferentAccess.new(
          program_id: lab_program.program_id,
          patient_id: patient.patient_id,
          specimen_type: { concept_id: specimen_type_id(lims_order.sample_type) },
          tests: lims_order.tests&.map { |test| { concept_id: test_type_id(test) } },
          requesting_clinician: requesting_clinician(lims_order.who_order_test),
          start_date: start_date(lims_order.date_created),
          target_lab: facility_name(lims_order.receiving_facility),
          order_location: facility_name(lims_order.sending_facility),
          reason_for_test: reason_for_test(lims_order.sample_priority)
        )
      end

      private

      # Translates a LIMS specimen name to an OpenMRS concept_id
      def specimen_type_id(lims_specimen_name)
        if lims_specimen_name == 'specimen_not_collected'
          return ConceptName.select(:concept_id).find_by_name!('Unknown')
        end

        concept = ConceptName.select(:concept_id).find_by_name(lims_specimen_name)
        return concept.concept_id if concept

        raise "Unknown specimen name: #{lims_specimen_name}"
      end

      # Translates a LIMS test type name to an OpenMRS concept_id
      def test_type_id(lims_test_name)
        concept = ConceptName.select(:concept_id).find_by_name(lims_test_name)
        return concept.concept_id if concept

        raise "Unknown test type: #{lims_test_name}"
      end

      # Extract requesting clinician name from LIMS
      def requesting_clinician(lims_user)
        # TODO: Extend requesting clinician to an obs tree having extra parameters
        # like phone number and ID to closely match the lims user.
        first_name = lims_user.first_name || ''
        last_name = lims_user.last_name || ''

        if first_name.blank? && last_name.blank?
          logger.warn('Missing requesting clinician name')
          return ''
        end

        "#{first_name} #{last_name}"
      end

      def start_date(lims_order_date_created)
        lims_order_date_created.to_datetime
      end

      # Parses a LIMS facility name
      def facility_name(lims_target_lab)
        return 'Unknown' if lims_target_lab == 'not_assigned'

        lims_target_lab
      end

      # Translates a LIMS priority to a concept_id
      def reason_for_test(lims_sample_priority)
        ConceptName.find_by_name!(lims_sample_priority).concept_id
      end
    end
  end
end
