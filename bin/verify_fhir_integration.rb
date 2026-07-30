# frozen_string_literal: true

require_relative '../config/environment'
require 'net/http'

puts "======================================================="
puts "  FHIR INTER-SYSTEM INTEGRATION VERIFICATION SCRIPT"
puts "======================================================="

# 1. Test DevBackend FHIR Metadata
puts "\n[1/5] Testing Legacy EMR (DevBackend) FHIR CapabilityStatement..."
meta = FhirSerializer.capability_statement
raise "DevBackend CapabilityStatement failed" unless meta[:resourceType] == 'CapabilityStatement' && meta[:fhirVersion] == '4.0.1'
puts "  [PASS] DevBackend FHIR CapabilityStatement valid (Version #{meta[:fhirVersion]})"

# 2. Create sample patient & order in DevBackend
puts "\n[2/5] Creating test Patient and Order in Legacy EMR..."
User.current = User.first || User.create!(username: 'admin')
person = Person.create!(gender: 'M', birthdate: Date.parse('1991-08-15'))
PersonName.create!(person_id: person.id, given_name: 'Tambosi', family_name: 'Phiri')
patient = Patient.create!(patient_id: person.id)

type = PatientIdentifierType.find_or_create_by!(name: Patient::NPID_NAME)
PatientIdentifier.create!(patient_id: patient.id, identifier_type: type.id, identifier: 'P987654321', location_id: 1)

concept = Concept.first || Concept.create!(retired: false)
ConceptName.find_or_create_by!(concept_id: concept.id, name: 'Viral Load')

encounter = Encounter.create!(
  patient_id: patient.id,
  encounter_type: EncounterType.first&.id || 1,
  program_id: Program.first&.id || 1,
  encounter_datetime: 1.minute.ago,
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
  accession_number: "ACC-FHIR-#{Time.now.to_i}"
)

puts "  [PASS] Patient ID: #{patient.id} (NPID: P987654321), Order ID: #{order.id}, Accession: #{order.accession_number}"

# 3. Serialize DevBackend Order to FHIR ServiceRequest
puts "\n[3/5] Serializing Order to FHIR ServiceRequest JSON..."
service_request = FhirSerializer.order_to_fhir_service_request(order)
patient_fhir = FhirSerializer.patient_to_fhir(patient)

raise "ServiceRequest serialization failed" unless service_request[:resourceType] == 'ServiceRequest'
raise "Patient serialization failed" unless patient_fhir[:resourceType] == 'Patient'
puts "  [PASS] ServiceRequest JSON generated successfully"
puts "         - ResourceType: #{service_request[:resourceType]}"
puts "         - Subject: #{service_request[:subject][:reference]} (#{service_request[:subject][:display]})"
puts "         - Test Code: #{service_request[:code][:text]}"

# 4. Simulate Ingestion into Lab System (mlab_api)
puts "\n[4/5] Ingesting FHIR ServiceRequest into Lab System (mlab_api logic)..."
lab_payload = {
  resourceType: 'Bundle',
  type: 'transaction',
  entry: [
    { resource: patient_fhir },
    { resource: service_request }
  ]
}

require 'shellwords'
require 'fileutils'

tmp_json_path = "/tmp/fhir_sr_#{Time.now.to_i}.json"
File.write(tmp_json_path, lab_payload.to_json)

runner_code = "require 'json'; payload = JSON.parse(File.read('#{tmp_json_path}'), symbolize_names: true); res = FhirService.process_incoming_service_request(payload); puts \"MLAB_SUCCESS:\#{res[:resourceType]}\""

output = Bundler.with_unbundled_env do
  `cd /home/gonjetso/mlab_api && bundle exec bin/rails runner #{Shellwords.escape(runner_code)}`
end
FileUtils.rm_f(tmp_json_path)

if output.include?('MLAB_SUCCESS:ServiceRequest')
  puts "  [PASS] Lab System successfully ingested FHIR ServiceRequest!"
  puts "         - Accession Number: #{order.accession_number}"
else
  puts "OUTPUT: #{output}"
  raise "mLab processing failed"
end

# 5. Retrieve CapabilityStatement from mLab
puts "\n[5/5] Checking Lab System (mlab_api) FHIR CapabilityStatement..."
mlab_cap_out = Bundler.with_unbundled_env do
  `cd /home/gonjetso/mlab_api && bundle exec bin/rails runner #{Shellwords.escape("puts FhirSerializer.capability_statement.to_json")}`
end
if mlab_cap_out.include?('CapabilityStatement')
  puts "  [PASS] Lab System CapabilityStatement retrieved successfully!"
end

puts "\n======================================================="
puts "  INTER-SYSTEM FHIR INTEGRATION VERIFICATION SUCCESSFUL!"
puts "======================================================="
