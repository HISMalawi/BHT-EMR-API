# frozen_string_literal: true

module OpdService
  # Provides various summary statistics for an ART patient
  class PatientSummary
    NPID_TYPE = 'National id'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    attr_reader :patient
    attr_reader :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def full_summary
      {
        patient_id: patient.patient_id,
        npid: npid || 'N/A',
        residence: residence
      }
    end

    def identifier(identifier_type_name)
      identifier_type = PatientIdentifierType.find_by_name(identifier_type_name)

      PatientIdentifier.where(
        identifier_type: identifier_type.patient_identifier_type_id,
        patient_id: patient.patient_id
      ).first&.identifier
    end

    def npid
      identifier(NPID_TYPE)
    end

    def residence
      address = patient.person.addresses[0]
      return 'N/A' unless address

      district = address.state_province || 'Unknown District'
      village = address.city_village || 'Unknown Village'
      "#{district}, #{village}"
    end

    # Returns the most recent value_datetime for patient's observations of the
    # given concept
    def recent_value_datetime(concept_name)
      concept = ConceptName.find_by_name(concept_name)
      date = Observation.where(concept_id: concept.concept_id,
                               person_id: patient.patient_id)\
                        .order(obs_datetime: :desc)\
                        .first\
                        &.value_datetime
      return nil if date.blank?

      date
    end

    # Method of last resort in finding a patient's earliest start date.
    #
    # Uses some cryptic SQL to come up with the value

    def name
      name = PersonName.where(person_id: patient.id)\
                       .order(:date_created)\
                       .first

      given_name = na

      "#{name.given_name} #{name.family_name}"
    end
  end
end
