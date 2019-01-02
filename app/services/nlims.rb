# frozen_string_literal: true

require 'ostruct'
require 'rest-client'

class NLims
  def initialize(config)
    @api_url = config['lims_url']
    @connection = nil
  end

  # We initially require a temporary authentication for user creation.
  # All other requests must start with an auth
  def temp_auth(username, password)
    response = get "authenticate/#{username}/#{password}"

    @connection = OpenStruct.new token: response['token']
  end

  def auth(username, password)
    response = get "re_authenticate/#{username}/#{password}"

    @connection = OpenStruct.new token: response['token']
  end

  def order_test(patient:, user:, specimen_type:, test_types:, date:, reason:,
                 target_lab:, requesting_clinician:)
    patient_name = patient.person.names.first
    user_name = user.person.names.first

    post 'create_order', district: 'Lilongwe',
                         health_facility_name: 'LL',
                         first_name: patient_name.given_name,
                         last_name: patient_name.family_name,
                         middle_name: '',
                         date_of_birth: patient.person.birthdate,
                         gender: patient.person.gender,
                         national_patient_id: patient.national_id,
                         phone_number: '',
                         who_order_test_last_name: user_name.family_name,
                         who_order_test_first_name: user_name.given_name,
                         who_order_test_id: user.id,
                         order_location: 'ART',
                         sample_type: specimen_type,
                         date_sample_drawn: date,
                         tests: test_types,
                         sample_priority: reason,
                         target_lab: target_lab,
                         art_start_date: 'unknown',
                         requesting_clinician: requesting_clinician
  end

  def patient_results(accession_number)
    get("query_results_by_tracking_number/#{accession_number}")
  end

  def all_results(patient)
    get("query_results_by_npid/#{patient.national_id}")
  end

  def patient_orders(accession_number)
    get("query_order_by_tracking_number/#{accession_number}")
  end

  def all_orders(patient)
    get("query_order_by_npid/#{patient.national_id}")
  end

  def specimen_types
    tests.keys
  end

  def test_types(specimen_type)
    tests[specimen_type]
  end

  def locations
    get('retrieve_order_location')
  end

  def labs
    get('retrieve_target_labs')
  end

  # Call temp_auth before this
  def create_user(body)
    post 'create_user', body
  end

  private

  def tests
    @tests ||= get('retrieve_test_Catelog')
  end

  def get(path)
    exec_request(path) do |full_path, headers|
      RestClient.get(full_path, headers)
    end
  end

  def post(path, body)
    exec_request(path) do |full_path, headers|
      RestClient.post(full_path, body.as_json, headers)
    end
  end

  def exec_request(path)
    response = yield expand_url(path), token: @connection&.token,
                                       content_type: 'application/json'

    response = JSON.parse(response)
    raise "Failed to communicate with LIMS: #{response['message']}" if response['error'] == true

    response['data']
  end

  def expand_url(path)
    "#{@api_url}/#{path}"
  end
end
