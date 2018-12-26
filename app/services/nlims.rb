# frozen_string_literal: true

require 'rest-client'

class NLims
  API_HOST = '127.0.0.1'
  API_PORT = '3002'
  API_PREFIX = 'api/v1'

  def order_test(patient:, user:, specimen_type:, test_types:, date:, reason:, target_lab:)
    patient_name = patient.person.names.first
    user_name = user.person.names.first

    response = post('create_order', {
      district: 'Lilongwe',
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
      requesting_clinician: ''
    })

    response.to_hash
  end

  def patient_results(accession_number)
    get("query_results_by_tracking_number/#{accession_number}")
  end

  def all_patient_results(patient)
    get("query_results_by_npid/#{patient.national_id}")
  end

  def results_trail(accession_number)
    get("query_order_by_tracking_number/#{accession_number}")
  end

  def all_results_trail(patient)
    get("query_order_by_npid/#{patient.national_id}")
  end

  def specimen_types
    tests.keys
  end

  def test_types(specimen_type)
    tests[specimen_type]
  end

  private

  def tests
    @tests ||= get('retrieve_test_Catelog')['data']
  end

  def get(path)
    headers = { token: '2Ucgn6jvDhtx', content_type: 'application/json' }
    content = RestClient.get(expand_path(path), headers)
    handle_response(JSON.parse(content))
  end

  def post(path, body)
    headers = { token: '2Ucgn6jvDhtx', content_type: 'application/json' }
    content = RestClient.post(expand_path(path), body, headers)
    handle_response(JSON.parse(content))
  end

  def expand_path(path)
    "http://#{API_HOST}:#{API_PORT}/#{API_PREFIX}/#{path}"
  end

  def handle_response(response)
    raise "Failed to communicate with LIMS: #{response['message']}" if response[:error]

    response
  end
end
