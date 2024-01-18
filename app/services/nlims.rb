# frozen_string_literal: true

require 'ostruct'
require 'rest-client'

class Nlims
  LIMS_TEMP_FILE = Rails.root.join('tmp/lims_connection.yml')
  LOGGER = Rails.logger

  def self.instance
    return @instance if @instance

    @instance = new
    @instance.connect(load_connection, on_auth: ->(connection) { save_connection(connection) })
    @instance
  end

  def self.load_connection
    YAML.load_file(LIMS_TEMP_FILE)
  rescue Errno::ENOENT
    nil
  end

  def self.save_connection(connection)
    File.open(LIMS_TEMP_FILE, 'w') do |fout|
      fout.write(connection.to_yaml)
    end
  end

  def initialize
    @api_prefix = config['lims_prefix'] || 'v1'
    @api_protocol = config['lims_protocol'] || 'http'
    @api_host = config['lims_host']
    @api_url = config['lims_url']
    @api_port = config['lims_port']
    @username = config['lims_username']
    @password = config['lims_password']
    @on_auth = nil
  end

  # We initially require a temporary authentication for user creation.
  # All other requests must start with an auth
  def temp_auth
    response = get "authenticate/#{config['lims_default_user']}/#{config['lims_default_password']}"

    @connection = OpenStruct.new(user: config['lims_default_user'], token: response['token'])
  end

  def connect(connection, on_auth: nil)
    @on_auth = on_auth if on_auth

    return auth unless connection&.user == @username # user has changed in config file

    @connection = connection
  end

  def legacy_order_test(patient, order)
    patient_name = patient.person.names.first
    user_name = User.current.person.names.first
    sample_type = order['sample_type']
    tests = [order['test_name']]
    reason_for_test = order['reason_for_test']
    sample_status = order['sample_status']
    target_lab = GlobalProperty.find_by_property('target.lab')&.property_value
    raise InvalidParameterError, 'Global property `target.lab` is not set' unless target_lab

    post 'create_order', district: 'Unknown',
                         health_facility_name: Location.current.name,
                         first_name: patient_name.given_name,
                         last_name: patient_name.family_name,
                         middle_name: patient_name.middle_name,
                         date_of_birth: patient.person.birthdate,
                         gender: patient.person.gender,
                         national_patient_id: patient.national_id,
                         phone_number: '',
                         who_order_test_last_name: user_name.family_name,
                         who_order_test_first_name: user_name.given_name,
                         who_order_test_id: User.current.id,
                         order_location: 'ART',
                         sample_type: sample_type,
                         tests: tests,
                         date_sample_drawn: order['date_sample_drawn'],
                         sample_priority: reason_for_test,
                         sample_status: sample_status,
                         art_start_date: 'unknown',
                         requesting_clinician: '',
                         target_lab: target_lab
  end

  def order_test(patient:, user:, test_type:, date:, reason:, requesting_clinician:)
    patient_name = patient.person.names.first
    user_name = user.person.names.first

    request_body = {
      district: 'Unknown',
      health_facility_name: Location.current.name,
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
      date_sample_drawn: date,
      tests: test_type,
      sample_priority: reason,
      art_start_date: 'unknown',
      requesting_clinician: requesting_clinician
    }

    post('request_order', request_body, api_version: 'api/v2') # Force version LIMS api version 2
  end

  def order_tb_test(patient:, user:, test_type:, date:, reason:, sample_type:, sample_status:,
    target_lab:, recommended_examination:, treatment_history:, sample_date:, sending_facility:, time_line: 'NA', requesting_clinician:)
    patient_name = patient.person.names.first
    user_name = user.person.names.first

    targeted_lab = GlobalProperty.find_by_property('target.lab')&.property_value
    raise InvalidParameterError, 'Global property `target.lab` is not set' unless target_lab

    response = post 'create_order', district: 'Lilongwe', #health facility district
          health_facility_name: sending_facility, #healh facility name
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
          order_location: 'TB',
          date_sample_drawn: date,
          tests: test_type,
          sample_priority: reason,
          art_start_date: 'not_applicable', #not applicable
          sample_type: sample_type, #Added to satify for TB
          sample_status: sample_status, #Added to satify for TB
          target_lab: targeted_lab || target_lab, #Added to satify for TB
          recommended_examination: recommended_examination, #Added to satify for TB
          treatment_history: treatment_history, #Added to satify for TB
          sample_date: sample_date, #Mofified 'Add an actual one' Removed this
          sending_facility: sending_facility,
          time_line: time_line,
          requesting_clinician: requesting_clinician

          response
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

  def specimen_types(test_type)
    tests[test_type]
  end

  def test_types
    tests.keys.sort
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

  def tests_without_results(npid)
    get("query_tests_with_no_results_by_npid/#{npid}")
  end

  def test_measures(test_name)
    test_name.gsub!(/\s+/, '_')
    get("query_test_measures/#{test_name}")
  end

  def update_test(values)
    post('update_test', values)
  end

  private

  def config
    @config ||= YAML.load_file("#{Rails.root}/config/application.yml")
  end

  def tests
    @tests ||= get('retrieve_test_Catelog')
  end

  def auth
    url = "re_authenticate/#{@username}/#{@password}"
    response = get(url, auto_login: false)

    @connection = OpenStruct.new(user: @username, token: response['token'])
    @on_auth&.call(@connection)

    @connection
  end

  def get(path, auto_login: true, api_version: nil)
    exec_request(path, auto_login: auto_login, api_version: api_version) do |full_path, headers|
      RestClient.get(full_path, headers)
    end
  end

  def post(path, body, api_version: nil)
    exec_request(path, api_version: api_version) do |full_path, headers|
      RestClient.post(full_path, body.as_json, headers)
    end
  end

  def exec_request(path, auto_login: true, api_version: nil,  &block)
    response = yield expand_url(path, api_version: api_version), token: @connection&.token,
                                                                 content_type: 'application/json'

    response = JSON.parse(response)
    if response['error'] == true
      if response['message'].match?(/token expired/i) && auto_login
        LOGGER.debug('LIMS token expired... Re-authenticating')
        return (auth && exec_request(path, auto_login: false, &block))
      end

      raise LimsError, "Failed to communicate with LIMS: #{response['message']}"
    end

    response['data']
  end

  def expand_url(path, api_version: nil)
    api_prefix = api_version || @api_prefix
    "#{@api_protocol}://#{@api_host}:#{@api_port}/#{api_prefix}/#{path}"
  end
end
