# frozen_string_literal: true

module FhirSerializer
  class << self
    def patient_to_fhir(patient)
      person = patient.person
      name = person&.names&.first
      gender = case person&.gender&.to_s&.upcase
               when 'M', 'MALE' then 'male'
               when 'F', 'FEMALE' then 'female'
               else 'unknown'
               end

      identifiers = []
      npid = patient.national_id rescue nil
      if npid.present?
        identifiers << {
          system: 'http://his.gov.mw/fhir/identifier/npid',
          value: npid,
          use: 'official'
        }
      end
      identifiers << {
        system: 'http://his.gov.mw/fhir/identifier/patient-id',
        value: patient.id.to_s,
        use: 'secondary'
      }

      given_names = [name&.given_name, name&.middle_name].compact.reject(&:empty?)
      given_names = ['Unknown'] if given_names.empty?

      {
        resourceType: 'Patient',
        id: patient.id.to_s,
        identifier: identifiers,
        name: [
          {
            family: name&.family_name || 'Unknown',
            given: given_names
          }
        ],
        gender: gender,
        birthDate: person&.birthdate&.iso8601
      }
    end

    def order_to_fhir_service_request(order)
      concept_name = order.concept&.concept_names&.first&.name || 'Lab Order'
      accession_number = order.accession_number || "ORD-#{order.id}"

      patient_ref = if order.patient
                      patient_name = order.patient.person&.names&.first
                      given = patient_name&.given_name
                      family = patient_name&.family_name
                      {
                        reference: "Patient/#{order.patient_id}",
                        display: [given, family].compact.join(' ')
                      }
                    else
                      { reference: "Patient/#{order.patient_id}" }
                    end

      requester_name = if order.provider
                         provider_name = order.provider.person&.names&.first
                         [provider_name&.given_name, provider_name&.family_name].compact.join(' ')
                       else
                         'Clinician'
                       end

      {
        resourceType: 'ServiceRequest',
        id: order.id.to_s,
        identifier: [
          {
            system: 'http://his.gov.mw/fhir/identifier/accession-number',
            value: accession_number
          }
        ],
        status: order.voided? ? 'revoked' : 'active',
        intent: 'order',
        code: {
          coding: [
            {
              system: 'http://his.gov.mw/fhir/concept',
              code: order.concept_id.to_s,
              display: concept_name
            }
          ],
          text: concept_name
        },
        subject: patient_ref,
        occurrenceDateTime: order.start_date&.iso8601 || order.date_created&.iso8601,
        authoredOn: order.date_created&.iso8601,
        requester: {
          display: requester_name.presence || 'Clinician'
        }
      }
    end

    def obs_to_fhir_observation(obs)
      concept_name = obs.concept&.concept_names&.first&.name || 'Observation'

      value_hash = if obs.value_numeric.present?
                     { valueQuantity: { value: obs.value_numeric, unit: obs.value_modifier || '' } }
                   elsif obs.value_text.present?
                     { valueString: obs.value_text }
                   elsif obs.value_coded.present?
                     coded_name = ConceptName.find_by(concept_id: obs.value_coded)&.name || obs.value_coded.to_s
                     { valueCodeableConcept: { text: coded_name } }
                   elsif obs.value_datetime.present?
                     { valueDateTime: obs.value_datetime.iso8601 }
                   else
                     { valueString: 'Recorded' }
                   end

      {
        resourceType: 'Observation',
        id: obs.id.to_s,
        status: obs.voided? ? 'cancelled' : 'final',
        category: [
          {
            coding: [
              {
                system: 'http://terminology.hl7.org/CodeSystem/observation-category',
                code: 'laboratory',
                display: 'Laboratory'
              }
            ]
          }
        ],
        code: {
          coding: [
            {
              system: 'http://his.gov.mw/fhir/concept',
              code: obs.concept_id.to_s,
              display: concept_name
            }
          ],
          text: concept_name
        },
        subject: {
          reference: "Patient/#{obs.person_id}"
        },
        effectiveDateTime: obs.obs_datetime&.iso8601
      }.merge(value_hash)
    end

    def order_to_fhir_diagnostic_report(order)
      concept_name = order.concept&.concept_names&.first&.name || 'Lab Report'
      accession_number = order.accession_number || "ORD-#{order.id}"
      obs_references = order.observations.map { |o| { reference: "Observation/#{o.id}" } }

      {
        resourceType: 'DiagnosticReport',
        id: order.id.to_s,
        identifier: [
          {
            system: 'http://his.gov.mw/fhir/identifier/accession-number',
            value: accession_number
          }
        ],
        status: order.observations.any? ? 'final' : 'registered',
        code: {
          coding: [
            {
              system: 'http://his.gov.mw/fhir/concept',
              code: order.concept_id.to_s,
              display: concept_name
            }
          ],
          text: concept_name
        },
        subject: {
          reference: "Patient/#{order.patient_id}"
        },
        issued: (order.observations.maximum(:obs_datetime) || order.date_created)&.iso8601,
        result: obs_references
      }
    end

    def bundle(resources, type: 'searchset')
      {
        resourceType: 'Bundle',
        type: type,
        total: resources.length,
        entry: resources.map { |r| { resource: r } }
      }
    end

    def capability_statement(service_name: 'Legacy EMR FHIR Server (DevBackend)')
      {
        resourceType: 'CapabilityStatement',
        status: 'active',
        date: Time.now.iso8601,
        publisher: 'EGPAF Malawi HIS / Ministry of Health',
        kind: 'instance',
        software: {
          name: service_name,
          version: '1.0.0'
        },
        fhirVersion: '4.0.1',
        format: ['application/fhir+json', 'application/json'],
        rest: [
          {
            mode: 'server',
            resource: [
              { type: 'Patient', interaction: [{ code: 'read' }, { code: 'search-type' }] },
              { type: 'ServiceRequest', interaction: [{ code: 'read' }, { code: 'create' }, { code: 'search-type' }] },
              { type: 'Observation', interaction: [{ code: 'read' }, { code: 'search-type' }] },
              { type: 'DiagnosticReport', interaction: [{ code: 'read' }, { code: 'search-type' }] }
            ]
          }
        ]
      }
    end
  end
end
