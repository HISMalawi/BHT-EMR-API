# frozen_string_literal: true

require 'yaml'
require 'rest-client'
require 'json'

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
user = User.find_by(username: 'admin')
User.current = user.present? ? user : User.unscoped.where(retired: 0).first
TEST_CATALOG_VERSION = 'v14'

def consolelog(text)
  puts "\n=======================================================\n"
  puts text
  puts "=======================================================\n"
end

def init_config
  @config ||= YAML.load_file(Rails.root.join('config', 'nlims.yaml'))
rescue Errno::ENOENT
  @config ||= YAML.load_file(Rails.root.join('config', 'application.yml'))
end

def url
  "#{@config['lims_protocol'] || 'http'}://#{@config['lims_host']}:#{@config['lims_port']}/api"
end

def authenticate
  consolelog 'Authenticating with LIMS'

  response = RestClient.post "#{url}/v1/login",
                             { username: @config['lims_username'], password: @config['lims_password'] }.to_json, content_type: :json

  raise "Failed to authenticate with LIMS: #{response.body}" if response.code != 200

  JSON.parse(response)['data']['token']
end

def fetch_test_catalog
  token = authenticate

  consolelog 'Authentication successful ...'

  headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }

  consolelog "Getting test catalog from LIMS - Catalog Version: #{TEST_CATALOG_VERSION}"

  uri = URI(url + "/v2/test_catalog/#{TEST_CATALOG_VERSION}")

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri, headers)
  request['token'] = token

  response = http.request(request)

  json = JSON.parse(response.read_body)
  puts json['message'] if json['error'].present?

  json['catalog']['test_types']
end

def add_to_concept_attributes(concept, name, code)
  # Find or create test catalogue name attribute
  name_attr = ConceptAttribute.find_or_initialize_by(
    concept: concept,
    attribute_type: nlims_test_catalogue_name,
    value_reference: name
  )

  if name_attr.new_record?
    name_attr.creator = User.current.user_id
    name_attr.date_created = Time.now
    name_attr.uuid = SecureRandom.uuid
    name_attr.save!
  end

  # Find or create NLIMS code attribute
  code_attr = ConceptAttribute.find_or_initialize_by(
    concept: concept,
    attribute_type: nlims_code_attribute_type,
    value_reference: code
  )

  if code_attr.new_record?
    code_attr.creator = User.current.user_id
    code_attr.date_created = Time.now
    code_attr.uuid = SecureRandom.uuid
    code_attr.save!
  end

  concept
end

def find_concept(name, code)
  # First, try to find by NLIMS code to ensure uniqueness
  existing_by_code = ConceptAttribute.where(
    attribute_type: nlims_code_attribute_type,
    value_reference: code
  ).first&.concept

  if existing_by_code.present?
    # Ensure this concept also has the test catalogue name attribute
    add_to_concept_attributes(existing_by_code, name, code)

    # Ensure preferred name is set
    preffered = ConceptName.where(concept: existing_by_code, locale_preferred: 1).count
    if preffered == 0
      concept_name = ConceptName.where(concept: existing_by_code).first
      concept_name.update_column(:locale_preferred, 1) if concept_name
    end

    return existing_by_code
  end

  # Handle special case where LIMS uses "Viral Load" but we want to map it to "HIV Viral Load"
  if name.downcase == 'viral load'
    # Find the HIV Viral Load concept
    hiv_vl_concept = ConceptName.find_by(name: 'HIV Viral Load')&.concept

    if hiv_vl_concept.present?
      # Check if a "Viral Load" concept name already exists
      viral_load_concept_name = ConceptName.unscoped.find_by(name: 'Viral Load', voided: 0)

      if viral_load_concept_name.present?
        # Update its concept_id to point to HIV Viral Load concept
        viral_load_concept_name.update!(concept_id: hiv_vl_concept.concept_id)
      else
        # Create "Viral Load" concept name that points to HIV Viral Load concept
        ConceptName.create!(
          concept: hiv_vl_concept,
          name: 'Viral Load',
          locale: 'en',
          concept_name_type: 'SYNONYM',
          creator: User.current.id,
          date_created: Time.now,
          uuid: SecureRandom.uuid
        )
      end

      # Delete any "Viral Load" concept attributes that are not associated with HIV Viral Load concept
      viral_load_concepts = ConceptName.unscoped.where('LOWER(name) = ?',
                                                       'viral load').where(voided: 0).pluck(:concept_id).uniq
      wrong_concept_ids = viral_load_concepts - [hiv_vl_concept.concept_id]

      ConceptAttribute.where(concept_id: wrong_concept_ids).delete_all if wrong_concept_ids.any?

      # Ensure preferred name is set
      preffered = ConceptName.where(concept: hiv_vl_concept, locale_preferred: 1).count
      if preffered == 0
        concept_name = ConceptName.where(concept: hiv_vl_concept).first
        concept_name.update_column(:locale_preferred, 1) if concept_name
      end

      return add_to_concept_attributes(hiv_vl_concept, name, code)
    end
  end

  # Try to find by name (scoped to current locale by default_scope)
  concept = ConceptName.find_by(name: name)&.concept

  if concept.present?
    preffered = ConceptName.where(concept:, locale_preferred: 1).count
    if preffered == 0
      concept_name = ConceptName.where(concept:).first
      concept_name.update_column(:locale_preferred, 1) if concept_name
    end

    return add_to_concept_attributes(concept, name, code)
  end

  # Try to find by name without locale scope (in case it exists in a different locale)
  concept = ConceptName.unscoped.find_by(name:, voided: 0)&.concept
  return add_to_concept_attributes(concept, name, code) if concept.present?

  # Try to find by short_name
  concept = Concept.where(short_name: name).first
  return add_to_concept_attributes(concept, name, code) if concept.present?

  # Create new concept and concept name
  concept = Concept.create!(
    short_name: name,
    creator: User.current.id,
    date_created: Time.now,
    concept_class: ConceptClass.find_by_name('Test'),
    concept_datatype: ConceptDatatype.find_by_name('Coded')
  )

  ConceptName.create!(
    concept:,
    name:,
    locale_preferred: 1,
    locale: 'en',
    concept_name_type: 'FULLY_SPECIFIED',
    creator: User.current.id,
    date_created: Time.now,
    uuid: SecureRandom.uuid
  )

  add_to_concept_attributes(concept, name, code)
end

def nlims_code_attribute_type
  # find or create the attribute type
  attribute_type = ConceptAttributeType.find_or_initialize_by(name: 'NLIMS CODE')
  return attribute_type unless attribute_type.new_record?

  attribute_type.description = 'NLIMS CODE'
  attribute_type.datatype = 'string'
  attribute_type.preferred_handler = 'org.openmrs.handler.concept.ConceptAttributeTypeHandler'
  attribute_type.min_occurs = 0
  attribute_type.max_occurs = 1
  attribute_type.creator = User.current.user_id
  attribute_type.date_created = Time.now
  attribute_type.uuid = SecureRandom.uuid
  attribute_type.save!

  attribute_type.reload
end

def nlims_test_catalogue_name
  # find or create the attribute type
  attribute_type = ConceptAttributeType.find_or_initialize_by(name: 'TEST CATALOGUE NAME')
  return attribute_type unless attribute_type.new_record?

  attribute_type.description = 'TEST CATALOGUE NAME'
  attribute_type.datatype = 'string'
  attribute_type.preferred_handler = 'org.openmrs.handler.concept.ConceptAttributeTypeHandler'
  attribute_type.min_occurs = 0
  attribute_type.max_occurs = 1
  attribute_type.creator = User.current.user_id
  attribute_type.date_created = Time.now
  attribute_type.uuid = SecureRandom.uuid
  attribute_type.save!

  attribute_type.reload
end

def find_or_create_concept_by_name(name, concept_class_name, concept_datatype_name)
  concept = ConceptName.unscoped.find_by(name: name, voided: 0)&.concept
  return concept if concept

  concept = Concept.create!(
    short_name: name,
    creator: User.current.user_id,
    date_created: Time.now,
    changed_by: User.current.user_id,
    date_changed: Time.now,
    concept_class: ConceptClass.find_by_name(concept_class_name),
    concept_datatype: ConceptDatatype.find_by_name(concept_datatype_name),
    uuid: SecureRandom.uuid
  )

  ConceptName.create!(
    concept: concept,
    name: name,
    locale_preferred: 1,
    locale: 'en',
    concept_name_type: 'FULLY_SPECIFIED',
    creator: User.current.user_id,
    date_created: Time.now,
    uuid: SecureRandom.uuid
  )

  concept
end

def specimen_type_concept
  @specimen_type_concept ||= find_or_create_concept_by_name('Specimen Type', 'Misc', 'N/A')
end

def test_type_concept
  @test_type_concept ||= find_or_create_concept_by_name('Test type', 'Test', 'N/A')
end

def lab_test_result_indicator_concept
  @lab_test_result_indicator_concept ||= find_or_create_concept_by_name('Lab test result indicator', 'Test', 'N/A')
end

def save_specimen_types(nlims_code, test_name, specimen_types)
  concept = find_concept(test_name, nlims_code)

  specimen_type_id = specimen_type_concept.concept_id
  test_type_id     = test_type_concept.concept_id

  # Add test type to "Test type" concept set if not already there
  set_exists = ConceptSet.find_by(concept_set: test_type_id, concept_id: concept.concept_id).present?

  unless set_exists
    ConceptSet.create!(
      concept_set: test_type_id,
      concept_id: concept.concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )
  end

  # Delete all existing specimen type associations for this test type before adding new ones
  # This removes: Test Type -> Specimen links (where Specimen is a Specimen Type)
  specimen_concept_ids = ConceptSet.where(concept_set: specimen_type_id).pluck(:concept_id)
  ConceptSet.where(
    concept_set: concept.concept_id,
    concept_id: specimen_concept_ids
  ).delete_all

  # Link specimens to test types: Test Type -> Specimen Type
  specimen_types.each do |specimen_type|
    specimen_type_name = specimen_type['name']
    specimen_type_nlims_code = specimen_type['nlims_code']

    specimen_concept = find_concept(specimen_type_name, specimen_type_nlims_code)

    # Add specimen to "Specimen Type" concept set if not already there
    cs = ConceptSet.find_or_initialize_by(
      concept_set: specimen_type_id,
      concept_id: specimen_concept.concept_id
    )

    if cs.new_record?
      cs.creator = User.current.id
      cs.date_created = Time.now
      cs.save!
    end

    # Link: Test Type contains Specimen Type
    scs = ConceptSet.find_or_initialize_by(
      concept_set: concept.concept_id,
      concept_id: specimen_concept.concept_id
    )

    next unless scs.new_record?

    scs.creator = User.current.id
    scs.date_created = Time.now
    scs.save!
  end
end

def save_measures(nlims_code, test_name, measures)
  concept = find_concept(test_name, nlims_code)

  lab_test_result_indicator_id = lab_test_result_indicator_concept.concept_id
  test_type_id = test_type_concept.concept_id

  # Add test type to "Test type" concept set if not already there
  set_exists = ConceptSet.find_by(concept_set: test_type_id, concept_id: concept.concept_id).present?

  unless set_exists
    ConceptSet.create!(
      concept_set: test_type_id,
      concept_id: concept.concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )
  end

  # Delete all existing measure associations for this test type before adding new ones
  # This removes: Test Type -> Measure links (where Measure is a Lab test result indicator)
  measure_concept_ids = ConceptSet.where(concept_set: lab_test_result_indicator_id).pluck(:concept_id)
  ConceptSet.where(
    concept_set: concept.concept_id,
    concept_id: measure_concept_ids
  ).delete_all

  measures.each do |measure|
    measure_name = measure['name']
    measure_nlims_code = measure['nlims_code']

    measure_concept = find_concept(measure_name, measure_nlims_code)

    # Add measure to "Lab test result indicator" concept set if not already there
    lcs = ConceptSet.find_or_initialize_by(
      concept_set: lab_test_result_indicator_id,
      concept_id: measure_concept.concept_id
    )

    if lcs.new_record?
      lcs.creator = User.current.id
      lcs.date_created = Time.now
      lcs.save!
    end

    # Link: Test type contains measure
    mcs = ConceptSet.find_or_initialize_by(
      concept_set: concept.concept_id,
      concept_id: measure_concept.concept_id
    )

    next unless mcs.new_record?

    mcs.creator = User.current.id
    mcs.date_created = Time.now
    mcs.save!
  end
end

def cleanup
  ConceptAttribute.where(attribute_type: nlims_test_catalogue_name).group(:value_reference).having('count(*) > 1')
                  .each do |duplicate|
    ConceptAttribute.where(
      attribute_type: nlims_test_catalogue_name,
      value_reference: duplicate.value_reference
    )[1..].each(&:delete)
  end
  ConceptAttribute.where(attribute_type: nlims_code_attribute_type).group(:value_reference).having('count(*) > 1')
                  .each do |duplicate|
    ConceptAttribute.where(
      attribute_type: nlims_code_attribute_type,
      value_reference: duplicate.value_reference
    )[1..].each(&:delete)
  end
end

def create_laboratory_investigations(test_catalog)
  labs = 'Laboratory Investigations'

  # Find or create the Laboratory Investigations concept
  lab_investigations_concept = ConceptName.find_by(name: labs)&.concept

  unless lab_investigations_concept
    lab_investigations_concept = Concept.create!(
      short_name: labs,
      creator: User.current.user_id,
      date_created: Time.now,
      concept_class: ConceptClass.find_by_name('Finding'),
      concept_datatype: ConceptDatatype.find_by_name('N/A')
    )

    ConceptName.create!(
      concept: lab_investigations_concept,
      name: labs,
      locale_preferred: 1,
      locale: 'en',
      concept_name_type: 'FULLY_SPECIFIED',
      creator: User.current.user_id,
      date_created: Time.now
    )
  end

  # Clear existing set members
  ConceptSet.where(concept_set: lab_investigations_concept.concept_id).delete_all

  # Collect all unique specimens from test catalog
  all_specimens = []
  test_catalog.each do |test_type|
    test_type['specimen_types'].each do |specimen_type|
      all_specimens << { name: specimen_type['name'], code: specimen_type['nlims_code'] }
    end
  end
  all_specimens.uniq! { |s| s[:name] }

  # Add each specimen as a set member of Laboratory Investigations
  all_specimens.each do |specimen|
    specimen_concept = find_concept(specimen[:name], specimen[:code])

    cs = ConceptSet.find_or_initialize_by(
      concept_set: lab_investigations_concept.concept_id,
      concept_id: specimen_concept.concept_id
    )

    next unless cs.new_record?

    cs.creator = User.current.user_id
    cs.date_created = Time.now
    cs.save!
  end

  consolelog "Created 'Laboratory Investigations' with #{all_specimens.count} specimen types"
end

init_config

ActiveRecord::Base.transaction do
  test_catalog = fetch_test_catalog

  # Create Laboratory Investigations concept set first
  create_laboratory_investigations(test_catalog)

  test_catalog.each do |test_type|
    measures = test_type['measures']
    specimen_types = test_type['specimen_types']
    nlims_code = test_type['nlims_code']
    test_name = test_type['name']

    save_specimen_types(nlims_code, test_name, specimen_types)
    save_measures(nlims_code, test_name, measures)
  end
  cleanup
end
