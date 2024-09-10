# frozen_string_literal: true

# this class will hold all whitelisted params for the whole application models
# rubocop: disable Metrics/ModuleLength
module ParamConstants
  PERSON_WHITELISTED_PARAMS = [
    :gender, :age, :birthdate, :birthdate_estimated, :dead, :deathdate, :cause_of_death, :deathdate_estimated,
    { names: %i[
        given_name middle_name family_name family_name2 preferred prefix family_name_prefix family_name_suffix degree
      ],
      addresses: %i[
        preferred address1 address2 city_village state_province country postal_code county_district address3 address4
        address5 address6 start_date end_date latitude longitude
      ],
      attributes: %i[
        attribute_type value hydrated_object
      ] }
  ].freeze

  ROLE_WHITELISTED_PARAMS = [
    :name, :description,
    { privileges: %i[name description],
      inherited_roles: [] }
  ].freeze

  USER_WHITELISTED_PARAMS = [
    :name, :description, :username, :password, :system_id, :secret_question, :secret_answer,
    { user_properties: {},
      person: PERSON_WHITELISTED_PARAMS,
      roles: ROLE_WHITELISTED_PARAMS,
      user: {} }
  ].freeze

  PATIENT_SEARCH_PARAMS = %i[
    given_name middle_name family_name family_name2 preferred prefix family_name_prefix family_name_suffix degree gender
    age birth_date birth_date_estimated dead death_date cause_of_death death_date_estimated
  ].freeze

  PATIENT_WHITELISTED_PARAMS = [
    :allergy_status,
    { patient: {},
      person: PERSON_WHITELISTED_PARAMS,
      identifiers: %i[
        identifier
        identifier_type
        location
        preferred
      ] }
  ].freeze

  VISIT_SEARCH_PARAMS = %i[
    date_started
    date_stopped
    patient_id
    visit_type_id
  ].freeze

  VISIT_WHITELISTED_PARAMS = [
    :id,
    :patient,
    :visit_type,
    :start_datetime,
    :location,
    :indication,
    :stop_datetime,
    { visit: {},
      encounters: [],
      attributes: %i[
        attribute_type
        value
      ] }
  ].freeze

  CONCEPT_NAME_WHITELISTED_PARAMS = [
    [
      :name,
      :id,
      :locale,
      :locale_preferred,
      :concept_name_type,
      { concept_name: {} }
    ]
  ].freeze

  CONCEPT_PARAMS = [
    :id,
    :uuid,
    :name,
    :concept_class,
    :short_name,
    :description,
    :form_text,
    :datatype,
    :class,
    :is_set,
    :version,
    { concept: {},
      names: CONCEPT_NAME_WHITELISTED_PARAMS }
  ].freeze

  CONCEPT_WHITELISTED_PARAMS = [
    CONCEPT_PARAMS, { set_members: CONCEPT_PARAMS }
  ].freeze

  ENCOUNTER_SEARCH_PARAMS = %i[
    encounter_type
    patient
    location
    form
    encounter_datetime
    visit
  ].freeze

  OBS_WHITELISTED_PARAMS = [
    :person, :concept, :encounter, :order, :obs_datetime, :location, :form_field_namespace, :accession_number,
    :value_group, :value_coded, :value_coded_name, :value_drug, :value_datetime, :value_numeric, :value_modifier,
    :value_text, :comments, :value_complex, :previous_version, :status, :interpretation, :comment, :value,
    :form_field_path, {
      observation: {}, group_members: []
    }
  ].freeze

  ENCOUNTER_WHITELISTED_PARAMS = [
    :encounter_type, :patient, :location, :form, :encounter_datetime, :visit, { obs: OBS_WHITELISTED_PARAMS,
                                                                                encounter: {} }
  ].freeze
end
# rubocop: enable Metrics/ModuleLength
