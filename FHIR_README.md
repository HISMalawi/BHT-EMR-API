# HL7 FHIR R4 Integration Guide (DevBackend)

## 📌 Overview

This repository (`DevBackend`) includes a native **HL7 FHIR (Fast Healthcare Interoperability Resources) R4** implementation. It enables standard-based interoperability between the Legacy EMR and external systems such as laboratory information management systems (e.g., `mlab_api`), national shared health record repositories, and third-party healthcare applications.

---

## 📂 File Structure

The FHIR integration consists of the following key files:

```
DevBackend/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── fhir_controller.rb     # FHIR REST API controller
│   └── services/
│       ├── fhir_serializer.rb            # Converts EMR models <-> FHIR R4 JSON
│       └── fhir_lab_client.rb            # HTTP Client for sending orders & fetching results
├── bin/
│   └── verify_fhir_integration.rb        # Verification script for FHIR pipeline
├── config/
│   └── routes.rb                         # FHIR routes under /api/v1/fhir/*
└── spec/
    └── requests/
        └── fhir_spec.rb                  # Request specs for FHIR endpoints
```

---

## 🛠️ FHIR R4 Mapping Specification

| EMR Domain Concept | FHIR Resource Type | Key Attributes Mapped |
| :--- | :--- | :--- |
| **Patient / Person** | `Patient` | Identifier (NPID `http://his.gov.mw/fhir/identifier/npid`), Given/Family Name, Gender, Birth Date |
| **Lab Order** | `ServiceRequest` | Identifier (Accession Number `http://his.gov.mw/fhir/identifier/accession-number`), Status, Code (Test Name), Subject |
| **Lab Result Measure** | `Observation` | Category (`laboratory`), Status (`final`), Subject, Value (`valueString` / `valueQuantity`) |
| **Lab Diagnostic Report** | `DiagnosticReport` | Status (`final`), Code, Subject, Contained Observations |
| **Server Conformance** | `CapabilityStatement` | Server software metadata, FHIR Version `4.0.1`, Supported Resource types & search parameters |

---

## 🌐 API Endpoint Reference

All FHIR endpoints are mounted under `/api/v1/fhir`:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/v1/fhir/metadata` | Returns system `CapabilityStatement` (FHIR R4 conformance statement) |
| `GET` | `/api/v1/fhir/Patient` | Search patients (`?identifier=P123` or `?name=John`) |
| `GET` | `/api/v1/fhir/Patient/:id` | Fetch single FHIR `Patient` resource |
| `GET` | `/api/v1/fhir/ServiceRequest` | List lab orders |
| `GET` | `/api/v1/fhir/ServiceRequest/:id` | Fetch single FHIR `ServiceRequest` resource |
| `POST` | `/api/v1/fhir/ServiceRequest` | Create lab order from FHIR `ServiceRequest` payload |
| `GET` | `/api/v1/fhir/Observation` | Fetch FHIR `Observation` lab results |
| `GET` | `/api/v1/fhir/Observation/:id` | Fetch single `Observation` resource |
| `GET` | `/api/v1/fhir/DiagnosticReport` | Fetch completed `DiagnosticReport` bundles |
| `GET` | `/api/v1/fhir/DiagnosticReport/:id` | Fetch single `DiagnosticReport` resource |
| `POST` | `/api/v1/fhir/send_order_to_lab` | Triggers `FhirLabClient` to send FHIR order to lab system |
| `GET` | `/api/v1/fhir/fetch_results_from_lab` | Triggers `FhirLabClient` to pull lab results from lab system |

---

## 💻 Inter-System Interoperability Workflow

### Sending an Order to mLab (`FhirLabClient`)

```ruby
# Example usage in Rails console or background job
order = Order.find(123)
client = FhirLabClient.new(lab_url: 'http://localhost:8005/api/v1/fhir/ServiceRequest')
response = client.send_order(order)
# => Returns HTTP response from mLab after ingesting FHIR ServiceRequest
```

### Fetching Lab Results from mLab (`FhirLabClient`)

```ruby
client = FhirLabClient.new(lab_url: 'http://localhost:8005/api/v1/fhir/DiagnosticReport')
report = client.fetch_results(accession_number: 'ACC-12345')
# => Returns parsed FHIR DiagnosticReport containing Observation results
```

---

## 🧪 Testing & Verification

### 1. Run Verification Script
To test inter-system communication between Legacy EMR and mLab:
```bash
bundle exec rails runner bin/verify_fhir_integration.rb
```

### 2. Run RSpec Request Specs
```bash
bundle exec rspec spec/requests/fhir_spec.rb
```

### 3. Browser Direct Access
Start Puma server:
```bash
bundle exec rails server -p 3000
```
Open in browser:
- `http://localhost:3000/api/v1/fhir/metadata`
- `http://localhost:3000/api/v1/fhir/Patient`
- `http://localhost:3000/api/v1/fhir/ServiceRequest`
