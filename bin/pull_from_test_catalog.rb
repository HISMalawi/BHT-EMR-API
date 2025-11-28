require 'yaml'
require 'rest-client'
require 'json'

Rails.logger = Logger.new($stdout)
ActiveRecord::Base.logger = Rails.logger
User.current = User.first

def consolelog text
  puts "\n=======================================================\n"
  puts text
  puts "=======================================================\n"
end

def init_config
  @config ||= YAML.load_file(Rails.root.join('config', 'application.yml'))
end

def url
  "#{@config['lims_protocol'] || 'http'}://#{@config['lims_host']}:#{@config['lims_port']}/api"
end

def authenticate
  consolelog "Authenticating with LIMS"

  response = RestClient.post "#{url}/v1/login", { username: @config['lims_username'], password: @config['lims_password']}.to_json, content_type: :json

  if response.code != 200
    raise "Failed to authenticate with LIMS: #{response.body}"
  end
  
  JSON.parse(response)['data']['token']
end

def fetch_test_catalog

  token = authenticate

  consolelog "Authentication successful ..."

  headers = {
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }

  consolelog "Getting test catalog from LIMS"

  uri = URI(url + '/v2/test_catalog/v1')
  
  http = Net::HTTP.new(uri.host, uri.port);
  request = Net::HTTP::Get.new(uri, headers)
  request["token"] = token

  response = http.request(request)

  json = JSON.parse(response.read_body)
  puts json["message"] if json['error'].present?
  
  json['catalog']['test_types']
end

def add_to_concept_attributes(concept, name)
  ConceptAttribute.create!(
    concept:,
    attribute_type: nlims_test_catalogue_name,
    value_reference: name
  )

  concept
end

def find_concept(name)
  concept = ConceptName.find_by(name:)&.concept
  
  if concept.present?
    preffered = ConceptName.where(concept:, locale_preferred: 1).count
    ConceptName.where(concept:).first.update!(locale_preferred: 1) if preffered == 0

    return add_to_concept_attributes(concept, name)
  end

  concept = Concept.create!(
    short_name: name,
    creator: User.current.user_id,
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
    creator: User.current.user_id,
    date_created: Time.now
  )

  ConceptAttribute.create!(
    concept:,
    attribute_type: nlims_test_catalogue_name,
    value_reference: name
  )
  
  add_to_concept_attributes(concept, name)
end

def nlims_test_catalogue_name
  ConceptAttributeType.find_by_name('TEST CATALOGUE NAME')
end

def nlims_code_attribute_type
  ConceptAttributeType.find_by_name('NLIMS CODE')
end


def save_specimen_types(nlims_code, test_name, specimen_types)
  concept ||= find_concept(test_name)

  # remove all existing specimen types
  specimen_type_id = ConceptName.find_by_name('Specimen Type').concept_id
  test_type_id     = ConceptName.find_by_name('Test type').concept_id

  set_exists = ConceptSet.find_by(concept_set: test_type_id, concept_id: concept.concept_id).present?
  
  ConceptSet.create!(
    concept_set: test_type_id,
    concept_id: concept.concept_id,
    creator: User.current.user_id,
    date_created: Time.now
  ) unless set_exists

  # add the new specimen types
  specimen_types.each do |specimen_type|
    specimen_type_name = specimen_type['name']
    specimen_type_nlims_code = specimen_type['nlims_code']

    specimen_concept_id = ConceptName.find_by_name(specimen_type_name.strip)&.concept_id
    specimen_concept_id ||= find_concept(specimen_type_name).concept_id

    ConceptSet.create!(
      concept_set: specimen_type_id,
      concept_id: specimen_concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )

    ConceptSet.create!(
      concept_set: concept.concept_id,
      concept_id: specimen_concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )

    # add specimen nlims code to concept attributes
    ConceptAttribute.create!(
      concept_id: specimen_concept_id,
      attribute_type: nlims_code_attribute_type,
      value_reference: specimen_type_nlims_code
    )

    ConceptAttribute.create!(
      concept_id: specimen_concept_id,
      attribute_type: nlims_test_catalogue_name,
      value_reference: specimen_type_name
    )
  end
end

def save_measures(nlims_code, test_name, measures)
  concept ||= find_concept(test_name)

  lab_test_result_indicator_id = ConceptName.find_by_name('Lab test result indicator').concept_id
  test_type_id = ConceptName.find_by_name('Test type').concept_id

  set_exists = ConceptSet.find_by(concept_set: test_type_id, concept_id: concept.concept_id).present?
  
  ConceptSet.create!(
    concept_set: test_type_id,
    concept_id: concept.concept_id,
    creator: User.current.user_id,
    date_created: Time.now
  ) unless set_exists

  measures.each do |measure|
    measure_name = measure['name']
    measure_nlims_code = measure['nlims_code']

    measure_concept_id = ConceptName.find_by_name(measure_name)&.concept_id
    measure_concept_id ||= find_concept(measure_name).concept_id

    # remove all measures for this test type
    sets = ConceptSet.where(
      concept_set: measure_concept_id, 
        concept_id: ConceptSet.where(
          concept_set: test_type_id, 
          concept_id: concept.concept_id
        ).select(:concept_id)
    ).pluck(:concept_set_id)

    ConceptSet.where(concept_set_id: sets).delete_all

    ConceptSet.create!(
      concept_set: lab_test_result_indicator_id,
      concept_id: measure_concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )

    ConceptSet.create!(
      concept_id: concept.concept_id,
      concept_set: measure_concept_id,
      creator: User.current.user_id,
      date_created: Time.now
    )

    # add measure nlims code to concept attributes
    ConceptAttribute.create!(
      concept_id: measure_concept_id,
      attribute_type: nlims_code_attribute_type,
      value_reference: measure_nlims_code
    )

    # add measure name to concept attributes
    ConceptAttribute.create!(
      concept_id: measure_concept_id,
      attribute_type: nlims_test_catalogue_name,
      value_reference: measure_name
    )
  end
end

init_config

ActiveRecord::Base.transaction do
  fetch_test_catalog.each do |test_type|
    measures = test_type['measures']
    specimen_types = test_type['specimen_types']
    nlims_code = test_type['nlims_code']
    test_name = test_type['name']

    save_specimen_types(nlims_code, test_name, specimen_types)
    save_measures(nlims_code, test_name, measures)
  end
end
