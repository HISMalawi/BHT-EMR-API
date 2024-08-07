# frozen_string_literal: true

require_relative 'config'
require_relative 'order_dto'
require_relative 'utils'

module Lab
  module Lims
    ##
    # Serializes a LabOrder into a LIMS OrderDto.
    module OrderSerializer
      class << self
        include Utils

        def serialize_order(order)
          serialized_order = Lims::Utils.structify(Lab::LabOrderSerializer.serialize_order(order))

          Lims::OrderDto.new(
            _id: Lab::LimsOrderMapping.find_by(order:)&.lims_id || serialized_order.accession_number,
            tracking_number: serialized_order.accession_number,
            sending_facility: current_facility_name,
            receiving_facility: serialized_order.target_lab,
            tests: serialized_order.tests.map { |test| format_test_name(test.name) },
            patient: format_patient(serialized_order.patient_id),
            order_location: format_order_location(serialized_order.encounter_id),
            sample_type: format_sample_type(serialized_order.specimen.name),
            sample_status: format_sample_status(serialized_order.specimen.name),
            sample_statuses: format_sample_status_trail(order),
            test_statuses: format_test_status_trail(order),
            who_order_test: format_orderer(order),
            districy: current_district, # yes districy [sic]...
            priority: format_sample_priority(serialized_order.reason_for_test.name),
            date_created: serialized_order.order_date,
            test_results: format_test_results(serialized_order),
            type: 'Order'
          )
        end

        private

        def format_order_location(encounter_id)
          location_id = Encounter.select(:location_id).where(encounter_id:)
          location = Location.select(:name)
                             .where(location_id:)
                             .first

          location&.name
        end

        # Format patient into a structure that LIMS expects
        def format_patient(patient_id)
          person = Person.find(patient_id)
          name = PersonName.find_by_person_id(patient_id)
          national_id = PatientIdentifier.joins(:type)
                                         .merge(PatientIdentifierType.where(name: 'National ID'))
                                         .where(patient_id:)
                                         .first
          phone_number = PersonAttribute.joins(:type)
                                        .merge(PersonAttributeType.where(name: 'Cell phone Number'))
                                        .where(person_id: patient_id)
                                        .first

          {
            first_name: name&.given_name,
            last_name: name&.family_name,
            id: national_id&.identifier,
            arv_number: find_arv_number(patient_id),
            art_regimen: find_current_regimen(patient_id),
            art_start_date: find_art_start_date(patient_id),
            dob: person.birthdate,
            phone_number: phone_number&.value || 'Unknown',
            gender: person.gender,
            email: nil
          }
        end

        def find_current_regimen(patient_id)
          regimen_data = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT patient_current_regimen(#{patient_id}, current_date()) regimen
          SQL
          return nil if regimen_data.blank?

          regimen_data['regimen']
        end

        def find_arv_number(patient_id)
          PatientIdentifier.joins(:type)
                           .merge(PatientIdentifierType.where(name: 'ARV Number'))
                           .where(patient_id:)
                           .first&.identifier
        end

        def find_art_start_date(patient_id)
          start_date = ActiveRecord::Base.connection.select_one <<~SQL
            SELECT date_antiretrovirals_started(#{patient_id}, current_date()) AS earliest_date
          SQL
          return nil if start_date.blank?

          start_date['earliest_date']
        end

        def format_sample_type(name)
          return 'not_specified' if name.casecmp?('Unknown')

          return 'CSF' if name.casecmp?('Cerebrospinal Fluid')

          name.titleize
        end

        def format_sample_status(name)
          name.casecmp?('Unknown') ? 'specimen_not_collected' : 'specimen_collected'
        end

        def format_sample_status_trail(order)
          return [] if order.concept_id == ConceptName.find_by_name!('Unknown').concept_id

          user = User.find(order.discontinued_by || order.creator)
          drawn_by = PersonName.find_by_person_id(user.user_id)
          drawn_date = order.discontinued_date || order.start_date

          [
            drawn_date.strftime('%Y%m%d%H%M%S') => {
              'status' => 'Drawn',
              'updated_by' => {
                'first_name' => drawn_by&.given_name || user.username,
                'last_name' => drawn_by&.family_name,
                'phone_number' => nil,
                'id' => user.username
              }
            }
          ]
        end

        def format_test_status_trail(order)
          tests = order.voided.zero? ? order.tests : Lab::LabOrderSerializer.voided_tests(order)

          tests.each_with_object({}) do |test, trail|
            test_name = format_test_name(ConceptName.find_by_concept_id!(test.value_coded).name)

            current_test_trail = trail[test_name] = {}

            current_test_trail[test.obs_datetime.strftime('%Y%m%d%H%M%S')] = {
              status: 'Drawn',
              updated_by: find_user(test.creator)
            }

            unless test.voided.zero?
              current_test_trail[test.date_voided.strftime('%Y%m%d%H%M%S')] = {
                status: 'Voided',
                updated_by: find_user(test.voided_by)
              }
            end

            next unless test.result

            current_test_trail[test.obs_datetime.strftime('%Y%m%d%H%M%S')] = {
              status: 'Verified',
              updated_by: find_user(test.result.creator)
            }
          end
        end

        def format_orderer(order)
          find_user(order.creator)
        end

        def format_test_results(order)
          order.tests&.each_with_object({}) do |test, results|
            next if test.result.nil? || test.result.empty?

            test_creator = User.find(Observation.find(test.result.first.id).creator)
            test_creator_name = PersonName.find_by_person_id(test_creator.person_id)

            results[format_test_name(test.name)] = {
              results: test.result.each_with_object({}) do |measure, measures|
                measures[format_test_name(measure.indicator.name)] = {
                  result_value: "#{measure.value_modifier}#{measure.value}"
                }
              end,
              result_date: test.result.first&.date,
              result_entered_by: {
                first_name: test_creator_name&.given_name,
                last_name: test_creator_name&.family_name,
                id: test_creator.username
              }
            }
          end
        end

        def format_test_name(test_name)
          return 'Viral Load' if test_name.casecmp?('HIV Viral load')

          return 'TB' if test_name.casecmp?('TB Program')

          test_name.titleize
        end

        def format_sample_priority(priority)
          return 'Routine' if priority&.casecmp?('Medical examination, routine')

          priority&.titleize
        end

        def current_health_center
          health_center = Location.current_health_center
          raise 'Current health center not set' unless health_center

          health_center
        end

        def current_district
          district = current_health_center.city_village \
                       || current_health_center.parent&.name \
                       || GlobalProperty.find_by_property('current_health_center_district')&.property_value

          return district if district

          GlobalProperty.create(property: 'current_health_center_district',
                                property_value: Lims::Config.application['district'],
                                uuid: SecureRandom.uuid)

          Config.application['district']
        end

        def current_facility_name
          current_health_center.name
        end

        def find_user(user_id)
          user = User.find(user_id)
          person_name = PersonName.find_by(person_id: user.person_id)
          phone_number = PersonAttribute.find_by(type: PersonAttributeType.where(name: 'Cell phone number'),
                                                 person_id: user.person_id)

          {
            first_name: person_name&.given_name,
            last_name: person_name&.family_name,
            phone_number: phone_number&.value,
            id: user.username
          }
        end
      end
    end
  end
end
