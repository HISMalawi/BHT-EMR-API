# frozen_string_literal: true

module ARTService
  module Reports
    module Pepfar
      ##
      # Common utilities for Pepfar reports
      module Utils
        ##
        # An array of all groups as required by PEPFAR.
        def pepfar_age_groups
          @pepfar_age_groups ||= [
            'Unknown',
            '0-5 months',
            '6-11 months',
            '12-23 months',
            '2-4 years',
            '5-9 years',
            '10-14 years',
            '15-17 years',
            '18-19 years',
            '20-24 years',
            '25-29 years',
            '30-34 years',
            '35-39 years',
            '40-44 years',
            '45-49 years',
            '50 plus years'
          ].freeze
        end

        ##
        # Returns the drilldown information for all specified patients (ie patient_ids)
        #
        # Information returned for a patient is as follows:
        #   * patient_id
        #   * arv_number or filing_number
        #   * age_group
        #   * birthdate
        #   * gender
        def pepfar_patient_drilldown_information(patients, current_date)
          raise ArgumentError, "current_date can't be nil" unless current_date

          Person.joins('LEFT JOIN patient_identifier ON patient_identifier.patient_id = person.person_id AND patient_identifier.voided = 0')
                .where(person_id: patients, patient_identifier: { identifier_type: pepfar_patient_identifier_type })
                .select("person.person_id AS patient_id,
                         person.gender,
                         person.birthdate,
                         cohort_disaggregated_age_group(person.birthdate, DATE(#{ActiveRecord::Base.connection.quote(current_date)})) AS age_group,
                         patient_identifier.identifier AS arv_number")
        end

        ##
        # Returns the preferred PEPFAR identifier type.
        #
        # In some clinics like Lighthouse Filing numbers are used exclusively and in other
        # sites, ARV Numbers are used.
        def pepfar_patient_identifier_type
          name = GlobalPropertyService.use_filing_numbers? ? 'Filing number' : 'ARV Number'
          PatientIdentifierType.where(name: name).select(:patient_identifier_type_id)
        end
      end
    end
  end
end
