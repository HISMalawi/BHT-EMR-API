# frozen_string_literal: true

require_relative 'exceptions'

module Lab
  module Lims
    ##
    # LIMS' Data Transfer Object for orders
    class OrderDto < ActiveSupport::HashWithIndifferentAccess
      include Utils

      ##
      # Unpacks a LIMS order into an object that OrdersService can handle
      def to_order_service_params(patient_id:)
        ActiveSupport::HashWithIndifferentAccess.new(
          program_id: lab_program.program_id,
          accession_number: self['tracking_number'],
          patient_id:,
          specimen: { concept_id: specimen_type_id },
          tests: self['tests']&.map { |test| { concept_id: test_type_id(test) } },
          requesting_clinician:,
          date: start_date,
          target_lab: facility_name(self['receiving_facility']),
          order_location: facility_name(self['sending_facility']),
          reason_for_test_id: reason_for_test
        )
      end

      private

      # Translates a LIMS specimen name to an OpenMRS concept_id
      def specimen_type_id
        lims_specimen_name = self['sample_type']&.strip&.downcase

        if lims_specimen_name.nil? || %w[specimen_not_collected not_assigned not_specified].include?(lims_specimen_name)
          return ConceptName.select(:concept_id).find_by_name!('Unknown').concept_id
        end

        concept = Utils.find_concept_by_name(lims_specimen_name)
        return concept.concept_id if concept

        raise UnknownSpecimenType, "Unknown specimen name: #{lims_specimen_name}"
      end

      # Translates a LIMS test type name to an OpenMRS concept_id
      def test_type_id(lims_test_name)
        lims_test_name = Utils.translate_test_name(lims_test_name)
        concept = Utils.find_concept_by_name(lims_test_name)
        return concept.concept_id if concept

        raise UnknownTestType, "Unknown test type: #{lims_test_name}"
      end

      # Extract requesting clinician name from LIMS
      def requesting_clinician
        return 'Unknown' unless self['who_order_test']

        # TODO: Extend requesting clinician to an obs tree having extra parameters
        # like phone number and ID to closely match the lims user.
        first_name = self['who_order_test']['first_name'] || ''
        last_name = self['who_order_test']['last_name'] || ''

        if first_name.blank? && last_name.blank?
          logger.warn('Missing requesting clinician name')
          return ''
        end

        "#{first_name} #{last_name}"
      end

      def start_date
        raise LimsException, 'Order missing created date' if self['date_created'].blank?

        Utils.parse_date(self['date_created'])
      end

      # Parses a LIMS facility name
      def facility_name(lims_target_lab)
        return 'Unknown' if lims_target_lab == 'not_assigned'

        lims_target_lab
      end

      # Translates a LIMS sample priority to a concept_id
      def reason_for_test
        return nil unless self['priority']

        name = case self['priority']
               when %r{Reapet / Missing}i then 'Repeat / Missing'
               else self['priority']
               end

        ConceptName.find_by_name!(name).concept_id
      end

      def lab_program
        Program.find_by_name!(Lab::Metadata::LAB_PROGRAM_NAME)
      end

      def unknown_concept
        ConceptName.find_by_name!('Unknown')
      end
    end
  end
end
