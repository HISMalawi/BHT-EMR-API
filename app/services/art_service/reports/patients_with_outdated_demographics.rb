# frozen_string_literal: true

module ARTService::Reports
  # Retrieves all current(neither dead nor transferred out) patients missing
  # any demographics or haven't had their demographics updated since the
  # given date
  class PatientsWithOutdatedDemographics
    attr_reader :date, :variant

    def initialize(start_date:, variant: 'poc', **_kwargs)
      @date = start_date
      @variant = parse_variant(variant)
    end

    def find_report
      patients = if variant == 'poc'
                   poc_patients_missing_demographics
                 else
                   emastercard_patients_missing_demographics
                 end

      patients.collect do |patient|
        {
          patient_id: patient.patient_id,
          arv_number: patient.arv_number,
          given_name: patient.given_name,
          family_name: patient.family_name,
          birthdate: patient[:birthdate],
          gender: patient[:gender],
          current_village: patient.current_village,
          current_traditional_authority: patient.current_traditional_authority,
          current_district: patient.current_district,
          home_village: patient.home_village,
          home_traditional_authority: patient.home_traditional_authority,
          home_district: patient.home_district,
          landmark: patient.landmark,
          address_last_updated_date: patient.address_last_updated_date
        }
      end
    end

    # Find all patients missing any of the following variables:
    #   - birthdate
    #   - gender
    #   - name
    #   - address
    def poc_patients_missing_demographics
      quoted_date = ActiveRecord::Base.connection.quote(date)

      Patient.find_by_sql(
        <<~SQL
          SELECT patient.patient_id AS patient_id,
                 patient_identifier.identifier AS arv_number,
                 person_name.given_name AS given_name,
                 person_name.family_name AS family_name,
                 person.birthdate AS birthdate,
                 person.gender AS gender,
                 person_address.city_village AS current_village,
                 person_address.township_division AS current_traditional_authority,
                 person_address.state_province AS current_district,
                 person_address.neighborhood_cell AS home_village,
                 person_address.county_district AS home_traditional_authority,
                 person_address.address2 AS home_district,
                 landmark.value AS landmark,
                 person_address.date_created AS address_last_updated_date
          FROM patient
          INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
          INNER JOIN patient_program ON patient_program.patient_id = patient.patient_id AND patient_program.program_id = 1
          INNER JOIN patient_state ON patient_state.patient_program_id = patient_program.patient_program_id
          LEFT JOIN patient_identifier ON patient_identifier.patient_id = patient.patient_id
            AND patient_identifier.voided = 0 AND patient_identifier.identifier_type = #{arv_number_id}
          LEFT JOIN person_name ON person_name.person_id = patient.patient_id AND person_name.voided = 0
          LEFT JOIN person_address ON person_address.person_id = patient.patient_id AND person_address.voided = 0
          LEFT JOIN person_attribute landmark ON landmark.person_id = patient.patient_id
            AND landmark.person_attribute_type_id = #{landmark_attribute_type_id}
          WHERE patient.voided = 0
            AND (patient_state.state != #{died_state_id}
                 OR (patient_state.state = #{transferred_out_state_id} AND patient_state.start_date < #{quoted_date}
                     AND (patient_state.end_date IS NULL OR patient_state.end_date > #{quoted_date})))
            AND ((person.birthdate IS NULL OR TRIM(COALESCE(person.gender, '')) = '')
                 OR (TRIM(COALESCE(person_name.given_name, '')) = '' OR TRIM(COALESCE(person_name.family_name, '')) = '')
                 OR (TRIM(COALESCE(person_address.city_village, '')) = ''
                     OR TRIM(COALESCE(person_address.township_division, '')) = ''
                     OR TRIM(COALESCE(person_address.state_province, '')) = ''
                     OR TRIM(COALESCE(person_address.neighborhood_cell, '') = '')
                     OR TRIM(COALESCE(person_address.county_district, '') = '')
                     OR TRIM(COALESCE(person_address.address2, '') = '')
                     OR person_address.date_created < #{quoted_date}))
          GROUP BY patient.patient_id
        SQL
      )
    end

    # Find all patients missing any of the following variables:
    #   - birthdate
    #   - gender
    #   - name
    #   - landmark
    #
    # NOTE: Old emastercard application did not collect a detailed and
    # properly formatted address. The address was collected as free text and
    # there was no standard provided for the address thus it's treated as
    # a landmark by this system. Even for the new eMastercard application
    # running atop this API, a free text alternative is provided if the
    def emastercard_patients_missing_demographics
      quoted_date = ActiveRecord::Base.connection.quote(date.to_s)

      Patient.find_by_sql(
        <<~SQL
          SELECT patient.patient_id AS patient_id,
                 patient_identifier.identifier AS arv_number,
                 person_name.given_name AS given_name,
                 person_name.family_name AS family_name,
                 person.birthdate AS birthdate,
                 person.gender AS gender,
                 person_address.city_village AS current_village,
                 person_address.township_division AS current_traditional_authority,
                 person_address.state_province AS current_district,
                 person_address.neighborhood_cell AS home_village,
                 person_address.county_district AS home_traditional_authority,
                 person_address.address2 AS home_district,
                 landmark.value AS landmark,
                 person_address.date_created AS address_last_updated_date
          FROM patient
          INNER JOIN person ON person.person_id = patient.patient_id AND person.voided = 0
          INNER JOIN patient_program ON patient_program.patient_id = patient.patient_id AND patient_program.program_id = 1
          INNER JOIN patient_state ON patient_state.patient_program_id = patient_program.patient_program_id
          LEFT JOIN patient_identifier ON patient_identifier.patient_id = patient.patient_id
            AND patient_identifier.voided = 0 AND patient_identifier.identifier_type = #{arv_number_id}
          LEFT JOIN person_name ON person_name.person_id = patient.patient_id AND person_name.voided = 0
          LEFT JOIN person_address ON person_address.person_id = patient.patient_id AND person_address.voided = 0
          LEFT JOIN person_attribute landmark ON landmark.person_id = patient.patient_id
            AND landmark.person_attribute_type_id = #{landmark_attribute_type_id}
          WHERE patient.voided = 0
            AND (patient_state.state != #{died_state_id}
                 OR (patient_state.state = #{transferred_out_state_id} AND patient_state.start_date < #{quoted_date}
                     AND (patient_state.end_date IS NULL OR patient_state.end_date > #{quoted_date})))
            AND ((person.birthdate IS NULL OR TRIM(COALESCE(person.gender, '')) = '')
                 OR (TRIM(COALESCE(person_name.given_name, '')) = '' OR TRIM(COALESCE(person_name.family_name, '')) = '')
                 OR (TRIM(COALESCE(landmark.value, '')) = '' OR landmark.date_created < #{quoted_date}))
          GROUP BY patient.patient_id
        SQL
      )
    end

    def arv_number_id
      @arv_number_id ||= PatientIdentifierType.find_by(name: 'ARV Number').patient_identifier_type_id
    end

    def died_state_id
      @died_state_id ||= ProgramWorkflowState.find_by_name_and_program(name: 'Died', program_id: 1).id
    end

    def transferred_out_state_id
      @transferred_out_state_id ||= ProgramWorkflowState.find_by_name_and_program(name: 'Patient transferred out', program_id: 1).id
    end

    def landmark_attribute_type_id
      @landmark_attribute_type_id ||= PersonAttributeType.find_by_name('Landmark Or Plot Number').id
    end

    def parse_variant(variant)
      variant = variant.downcase

      return variant if %w[poc emastercard].include?(variant)

      raise InvalidParameterError, "Invalid report variant '#{variant}'; expected poc or emastercard"
    end
  end
end
