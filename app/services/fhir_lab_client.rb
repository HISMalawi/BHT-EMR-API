# frozen_string_literal: true

require 'rest-client'
require 'json'

module FhirLabClient
  class << self
    def send_order_to_lab(order, lab_fhir_url: nil, auth_token: nil)
      url = lab_fhir_url || default_lab_url
      service_request = FhirSerializer.order_to_fhir_service_request(order)

      # Attach Patient resource details if available for full FHIR bundle submission
      patient = order.patient
      patient_fhir = patient ? FhirSerializer.patient_to_fhir(patient) : nil

      payload = {
        resourceType: 'Bundle',
        type: 'transaction',
        entry: [
          (patient_fhir ? { resource: patient_fhir } : nil),
          { resource: service_request }
        ].compact
      }

      headers = {
        content_type: 'application/fhir+json',
        accept: 'application/fhir+json'
      }
      headers['Authorization'] = auth_token if auth_token.present?

      response = RestClient.post("#{url}/ServiceRequest", payload.to_json, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      { error: e.message, response: e.response&.body }
    rescue StandardError => e
      { error: e.message }
    end

    def fetch_results_from_lab(accession_number, lab_fhir_url: nil, auth_token: nil)
      url = lab_fhir_url || default_lab_url
      headers = { accept: 'application/fhir+json' }
      headers['Authorization'] = auth_token if auth_token.present?

      response = RestClient.get("#{url}/DiagnosticReport?identifier=#{CGI.escape(accession_number)}", headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      { error: e.message, response: e.response&.body }
    rescue StandardError => e
      { error: e.message }
    end

    private

    def default_lab_url
      config = YAML.load_file("#{Rails.root}/config/application.yml") rescue {}
      config['lab_fhir_url'] || 'http://localhost:3001/api/v1/fhir'
    end
  end
end
