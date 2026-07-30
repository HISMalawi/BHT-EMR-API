# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FHIR API', type: :request do
  describe 'GET /api/v1/fhir/metadata' do
    it 'returns FHIR capability statement metadata' do
      get '/api/v1/fhir/metadata'
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['resourceType']).to eq('CapabilityStatement')
      expect(json['fhirVersion']).to eq('4.0.1')
    end
  end

  describe 'FHIR Serializer' do
    it 'serializes patient to FHIR Patient resource' do
      person = Person.create!(
        gender: 'M',
        birthdate: Date.parse('1990-01-01')
      )
      PersonName.create!(
        person_id: person.id,
        given_name: 'John',
        family_name: 'Doe'
      )
      patient = Patient.create!(patient_id: person.id)

      fhir_patient = FhirSerializer.patient_to_fhir(patient)
      expect(fhir_patient[:resourceType]).to eq('Patient')
      expect(fhir_patient[:id]).to eq(patient.id.to_s)
      expect(fhir_patient[:gender]).to eq('male')
      expect(fhir_patient[:name].first[:given]).to include('John')
      expect(fhir_patient[:name].first[:family]).to eq('Doe')
    end

    it 'serializes order to FHIR ServiceRequest resource' do
      concept = Concept.first || Concept.create!(retired: false)
      ConceptName.find_or_create_by!(concept_id: concept.id, name: 'Viral Load')

      person = Person.create!(gender: 'F', birthdate: Date.parse('1995-05-05'))
      PersonName.create!(person_id: person.id, given_name: 'Jane', family_name: 'Smith')
      patient = Patient.create!(patient_id: person.id)

      encounter = Encounter.create!(
        patient_id: patient.id,
        encounter_type: EncounterType.first&.id || 1,
        program_id: Program.first&.id || 1,
        encounter_datetime: Time.now,
        provider_id: person.id,
        location_id: 1
      )
      user = User.first || User.create!(username: 'admin')
      order = Order.create!(
        patient_id: patient.id,
        encounter_id: encounter.id,
        concept_id: concept.id,
        order_type_id: 1,
        orderer: user.id,
        provider: user,
        start_date: Time.now,
        accession_number: 'ACC-12345'
      )

      fhir_request = FhirSerializer.order_to_fhir_service_request(order)
      expect(fhir_request[:resourceType]).to eq('ServiceRequest')
      expect(fhir_request[:id]).to eq(order.id.to_s)
      expect(fhir_request[:subject][:reference]).to eq("Patient/#{patient.id}")
      expect(fhir_request[:code][:text]).to eq('Viral Load')
    end
  end
end
