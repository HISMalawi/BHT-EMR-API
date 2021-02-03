# frozen_string_literal: true

module ARTService
  # Provides various summary statistics for an ART patient
  class PatientSummary
    NPID_TYPE = 'National id'
    ARV_NO_TYPE = 'ARV Number'
    FILING_NUMBER = 'Filing number'
    ARCHIVED_FILING_NUMBER = 'Archived filing number'

    SECONDS_IN_MONTH = 2_592_000

    include ModelUtils

    attr_reader :patient
    attr_reader :date

    def initialize(patient, date)
      @patient = patient
      @date = date
    end

    def full_summary
      art_start_date, art_duration = art_period
      {
        patient_id: patient.patient_id,
        npid: npid || 'N/A',
        arv_number: arv_number || 'N/A',
        filing_number: filing_number || 'N/A',
        current_outcome: current_outcome,
        residence: residence,
        art_duration: art_duration || 'N/A',
        current_regimen: current_regimen,
        art_start_date: art_start_date&.strftime('%d/%m/%Y') || 'N/A',
        reason_for_art: art_reason
      }
    end

    def identifier(identifier_type_name)
      identifier_type = PatientIdentifierType.where(name: identifier_type_name)

      PatientIdentifier.find_by(
        identifier_type: identifier_type.select(:patient_identifier_type_id),
        patient_id: patient.patient_id
      )&.identifier
    end

    def npid
      identifier(NPID_TYPE)
    end

    def arv_number
      identifier(ARV_NO_TYPE)
    end

    def residence
      address = patient.person.addresses[0]
      return 'N/A' unless address

      district = address.state_province || 'Unknown District'
      village = address.city_village || 'Unknown Village'
      "#{district}, #{village}"
    end

    def current_regimen
      patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
      quoted_date = ActiveRecord::Base.connection.quote(date.to_date)

      ActiveRecord::Base.connection.select_one(
        "SELECT patient_current_regimen(#{patient_id}, #{quoted_date}) as regimen"
      )['regimen'] || 'N/A'
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("Failed tor retrieve patient current regimen: #{e}:")
      'N/A'
    end

    def current_outcome
      patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)
      quoted_date = ActiveRecord::Base.connection.quote(date)

      ActiveRecord::Base.connection.select_one(
        "SELECT patient_outcome(#{patient_id}, #{quoted_date}) as outcome"
      )['outcome'] || 'UNKNOWN'
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("Failed tor retrieve patient current outcome: #{e}:")
      'UNKNOWN'
    end

    def art_reason
      concept = concept('Reason for ART eligibility')
      return 'UNKNOWN' unless concept

      obs_list = Observation.where concept_id: concept.concept_id,
                                   person_id: patient.patient_id
      obs_list = obs_list.order(date_created: :desc).limit(1)
      return 'N/A' if obs_list.empty?

      obs = obs_list[0]

      reason_concept = ConceptName.unscoped.find_by(concept_id: obs.value_coded.to_i,
                                                    concept_name_type: 'FULLY_SPECIFIED')
      reason_concept&.name || 'N/A'
    end

    def art_period
      sdate = ActiveRecord::Base.connection.select_one <<EOF
      SELECT date_antiretrovirals_started(#{patient.patient_id}, current_date()) AS earliest_date;
EOF

      start_date = sdate['earliest_date'].to_time rescue nil

      return [nil, nil] unless start_date

      duration = ((Time.now - start_date) / SECONDS_IN_MONTH).to_i # Round off to preceeding integer
      [start_date, duration] # Reformat the date for the lazy frontenders
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
    def earliest_start_date_at_clinic
      patient_id = ActiveRecord::Base.connection.quote(patient.patient_id)

      row = ActiveRecord::Base.connection.select_one <<~SQL
        SELECT earliest_start_date_at_clinic(#{patient_id}) as date
      SQL

      row['date']&.to_datetime
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("Failed to retrieve patient earliest_start_date_at_clinic: #{e}:")
      nil
    end

    def filing_number
      filing_number = identifier(FILING_NUMBER)
      return { number: filing_number || 'N/A', type: FILING_NUMBER } if filing_number

      filing_number = identifier(ARCHIVED_FILING_NUMBER)
      return { number: filing_number, type: ARCHIVED_FILING_NUMBER } if filing_number

      { number: 'N/A', type: 'N/A' }
    end

    def art_start_date
      art_period[0]
    end

    def name
      name = PersonName.where(person_id: patient.id)\
                       .order(:date_created)\
                       .first

      "#{name.given_name} #{name.family_name}"
    end
  end
end
