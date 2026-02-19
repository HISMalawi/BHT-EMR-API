# BHT-EMR-API Streaming System Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Setup Instructions](#setup-instructions)
4. [How It Works](#how-it-works)
5. [Monitoring Jobs](#monitoring-jobs)
6. [Troubleshooting](#troubleshooting)
7. [API Endpoints](#api-endpoints)
8. [Configuration Reference](#configuration-reference)

---

## Overview

The Streaming System is a real-time data synchronization mechanism that sends **complete patient visit data from the ART Module** from the BHT-EMR-API to a Central Data Repository (CDR) or Data Warehouse. It uses **SolidQueue**, a database-backed job queue for Ruby on Rails, to manage asynchronous job processing and ensure reliable delivery of patient data.

### Key Features

- **Reliable Job Processing**: Database-backed queue persists jobs across service restarts
- **Scheduled Streaming**: Automatically streams incomplete and missed visits on a daily schedule
- **Real-time Monitoring**: Web-based dashboard to monitor job status and performance
- **Error Tracking**: Failed jobs are logged and accessible for investigation
- **Multi-environment Support**: Works seamlessly across development, test, and production environments
- **Configurable Concurrency**: Adjust worker threads and processes based on workload

### Limitations

⚠️ **Important:** Please note the following constraints:
- **Visit Completion Requirement**: Only **complete visits** are streamed to the CDR. Incomplete or draft visits are identified and queued for completion before streaming
- **Module Support**: Streaming is currently **only supported for the ART (Antiretroviral Therapy) Module**. Other modules (HTS, ANC, TB, OPD, etc.) are not supported at this time

Future releases may extend support to additional modules.

---

## Architecture

### Components

#### 1. **SolidQueue** (Job Queue)
- Database-backed job queue system
- Stores jobs in a separate `solid_queue_*` database
- Uses dispatchers to retrieve jobs and workers to process them
- Configuration: `config/queue.yml`

#### 2. **Jobs**

| Job | Purpose | Queue | Schedule |
|-----|---------|-------|----------|
| `StreamingJob` | Core job that streams individual patient visits | default | On-demand |
| `StreamIncompleteVisitsJob` | Streams visits with incomplete data | incomplete_visits | Daily at 1 AM |
| `StreamMissedVisitsJob` | Streams visits that were missed | finished | Daily at 1 AM |
| `ClearFinishedJob` | Cleans up finished job records | finished | Daily at 1 AM |

#### 3. **Services**

| Service | Purpose |
|---------|---------|
| `StreamingService` | Handles the actual data transmission to CDR |
| `ArtService::PatientStreamBuilder` | Builds analytical payload for streaming |

#### 4. **Controllers**

| Endpoint | Purpose |
|----------|---------|
| `/streaming` | SolidQueue Monitor Dashboard |
| `/api/v1/streaming/stats` | JSON statistics endpoint |
| `/api/v1/streaming/failed` | JSON failed jobs endpoint |

#### 5. **Databases**

```
Primary Database (EMR Data)
├── Encounters
├── Patients
├── Observations
├── Orders
├── Global Properties
└── ...

Queue Database (Job Storage - SolidQueue)
├── ar_internal_metadata
├── schema_migrations
├── solid_queue_blocked_executions
├── solid_queue_claimed_executions
├── solid_queue_failed_executions
├── solid_queue_jobs
├── solid_queue_pauses
├── solid_queue_processes
├── solid_queue_ready_executions
├── solid_queue_recurring_executions
├── solid_queue_recurring_tasks
├── solid_queue_scheduled_executions
└── solid_queue_semaphores
```

#### SolidQueue Tables Reference

| Table | Purpose | Key Columns | Status |
|-------|---------|-------------|--------|
| `solid_queue_jobs` | Stores all enqueued jobs | `id`, `job_class`, `arguments`, `queue`, `created_at` | ✓ |
| `solid_queue_ready_executions` | Jobs ready to be processed | `id`, `job_id`, `queue` | ✓ |
| `solid_queue_scheduled_executions` | Jobs scheduled for future execution | `id`, `job_id`, `scheduled_at`, `queue` | ✓ |
| `solid_queue_claimed_executions` | Jobs currently being processed | `id`, `job_id`, `process_id`, `created_at` | ✓ |
| `solid_queue_finished_executions` | Completed jobs (successful) | `id`, `job_id`, `created_at`, `finished_at` | ✗ Not used in this implementation |
| `solid_queue_failed_executions` | Failed jobs with error info | `id`, `job_id`, `error`, `created_at` | ✓ |
| `solid_queue_blocked_executions` | Jobs blocked by dependencies | `id`, `job_id`, `block_id` | ✓ |
| `solid_queue_processes` | Worker process information | `id`, `kind`, `hostname`, `pid`, `last_heartbeat_at` | ✓ |
| `solid_queue_pauses` | Queue pause states | `id`, `queue`, `paused_at` | ✓ |
| `solid_queue_recurring_tasks` | Scheduled recurring job definitions | `id`, `key`, `class`, `schedule`, `queue` | ✓ |
| `solid_queue_recurring_executions` | Execution history of recurring tasks | `id`, `recurring_task_id`, `scheduled_at`, `created_at` | ✓ |
| `solid_queue_semaphores` | Concurrency control locks | `id`, `key`, `value`, `expires_at` | ✓ |
| `schema_migrations` | Database schema version tracking | `version` | ✓ |
| `ar_internal_metadata` | Rails internal metadata | `key`, `value` | ✓ |

#### Job Lifecycle Through SolidQueue Tables

Jobs flow through SolidQueue tables in the following lifecycle:

```
1. Job Created
   └─> solid_queue_jobs (inserted)

2. Job Scheduled (if future)
   └─> solid_queue_scheduled_executions
       └─ Dispatcher moves to step 3 when time arrives

3. Job Ready to Process
   └─> solid_queue_ready_executions
       └─ Worker picks up and moves to step 4

4. Job Processing
   └─> solid_queue_claimed_executions
       └─ Worker executes the job

5a. Job Succeeds (removed from execution tables)
    └─ No record persisted (job completes naturally)

5b. Job Fails
    └─> solid_queue_failed_executions ✗

5c. Job Blocked
    └─> solid_queue_blocked_executions (dependencies)
```

**Note:** This implementation does not persist successful job completions to a separate table. Successful jobs are simply removed from the queue once executed. Use the web dashboard or logs to track completed jobs.

#### Streaming-Specific Table Usage

| Component | Primary Tables | Purpose |
|-----------|---|---|
| **StreamingJob** | `solid_queue_jobs`, `solid_queue_ready_executions` | On-demand patient visit streaming |
| **StreamIncompleteVisitsJob** | `solid_queue_jobs`, `solid_queue_recurring_executions` | Daily incomplete visit detection |
| **StreamMissedVisitsJob** | `solid_queue_jobs`, `solid_queue_recurring_executions` | Daily missed visit detection |
| **ClearFinishedJob** | `solid_queue_finished_executions`, `solid_queue_jobs` | Cleans up old completed jobs |
| **SolidQueueMonitor** | All `solid_queue_*` tables | Dashboard monitoring and visualization |
| **Dispatcher** | `solid_queue_processes`, `solid_queue_scheduled_executions`, `solid_queue_ready_executions` | Picks up scheduled/ready jobs |
| **Workers** | `solid_queue_claimed_executions`, `solid_queue_processes` | Executes jobs and updates status |

---

## Setup Instructions

### Prerequisites

- MySQL/MariaDB database server
- Ruby on Rails environment configured
- Network access to CDR endpoint
- Appropriate database credentials

### Step 1: Run the Setup Script

Execute the database configuration script for your environment:

```bash
bin/setup_streaming.sh development
# or for production:
bin/setup_streaming.sh production
```

**What this script does:**
- Backs up your current `database.yml`
- Configures database connections with `primary` and `queue` databases
- Creates separate queue databases (`solid_queue_dev_*` or `solid_queue_prod_*`)
- Loads the SolidQueue schema into the queue database
- Enables the `patient.streaming` global property

### Step 2: Configure Application Settings

Edit `config/application.yml` and add/verify the CDR configuration:

```yaml
cdr:
  url: http://cdr-server.example.com/api/v1/stream
  username: your_api_username
  password: your_api_password
```

**Configuration Parameters:**
- `url`: The CDR endpoint URL that receives streamed data
- `username`: API authentication username
- `password`: API authentication password

### Step 3: Configure Queue Settings

The setup script automatically copies example files. Verify these files exist:

- `config/queue.yml` - Job queue worker configuration
- `config/recurring.yml` - Scheduled job definitions

**Example queue.yml:**
```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: 1
      polling_interval: 0.1
```

### Step 4: Run Rails Setup Task

```bash
# For development
RAILS_ENV=development bundle exec rake streaming:setup

# For production
RAILS_ENV=production bundle exec rake streaming:setup
```

**What this task accomplishes:**
- Creates the queue database (`solid_queue_dev_*` or `solid_queue_prod_*`)
- Loads the SolidQueue schema into the queue database
- Creates the global property for streaming control
- Enables streaming in the EMR system

#### Global Property Created

The setup task automatically creates the following global property:

```sql
SELECT * FROM global_property WHERE property LIKE '%stream%';
```

**Result:**
| Property | Value | Description | UUID |
|----------|-------|-------------|------|
| `patient.streaming` | `active` | Enable/Disable patient streaming | `6968ac8d-0cca-11f1-9b35-0242ac110002` |

This global property controls whether streaming is enabled in the system. When set to `active`, the streaming functionality is available. You can disable streaming by changing the `property_value` to any other value.

### Step 5: Streaming Workers Start Automatically

**Important Note:** After running the `rake streaming:setup` task, you **do not need to manually start the workers**. The Rails application automatically manages SolidQueue workers based on the environment configuration.

**Automatic Startup Behavior:**
- Workers are managed by the Rails application startup process
- The queue dispatcher automatically starts when the application boots
- Workers are configured to run with the settings in `config/queue.yml`
- For production, ensure your application startup process (systemd, Docker, etc.) is properly configured

**Manual Worker Control (if needed):**

If you need to manually start workers for development or debugging:

```bash
# Start SolidQueue workers manually
bundle exec jobs exec

# In a separate terminal, start the dispatcher manually (if not using the bundled dispatcher)
bundle exec bundle exec solid_queue:dispatcher
```

**For Production Deployments:**
Consider using a systemd service or process manager like Puma to manage the application and its workers. See `create_puma_service.sh` in the `bin/` directory for reference.

**Verify Workers are Running:**

```bash
# Check if queue database has active processes
mysql -u user -p database -e "SELECT COUNT(*) FROM solid_queue_processes WHERE last_heartbeat_at > NOW() - INTERVAL 1 MINUTE;"

# Expected: Should show 1 or more active processes
```

---

## How It Works

### Data Flow

```
Patient Encounter Created/Updated
          ↓
  Workflow Service Triggered
          ↓
  Check Streaming Global Property (patient.streaming = active)
          ↓
  Enqueue StreamingJob
          ↓
  SolidQueue Dispatcher Picks Up Job
          ↓
  SolidQueue Worker Processes Job
          ↓
  StreamingService Compiles Payload
          ↓
  StreamingService Sends to CDR
          ↓
  CDR Receives and Processes Data
```

**Note:** The streaming workflow checks the `patient.streaming` global property before enqueueing jobs. This property is automatically created and set to `active` during setup, enabling the streaming functionality. You can disable streaming without uninstalling by changing this property value in the database.

### Job Processing Flow

#### 1. **StreamingJob (On-Demand)**

When triggered manually or by application logic:

```ruby
StreamingJob.perform_later(
  patient_id: 123,
  program_id: 1,
  date: '2024-02-19'
)
```

**Processing Steps:**
1. Retrieve patient record from primary database
2. Fetch encounters for the specified program and date
3. Build raw data payload (patient info, encounters, program data)
4. Build analytical payload using `ArtService::PatientStreamBuilder`
5. Compress payload using gzip
6. Send to CDR via REST API
7. Log success or failure

#### 2. **StreamIncompleteVisitsJob (Scheduled)**

**Trigger:** Daily at 1 AM

**Purpose:** Identify ART Module visits that were incomplete the previous day for completion and subsequent streaming.

**Logic:**
1. Identify incomplete visits from the previous day using `ArtService::DataCleaningTool`
2. Job operates **exclusively on ART Module visits** (program_id = 1)
3. Only **complete visits** are enqueued for streaming; incomplete visits remain unstreamed
4. Enqueues a `StreamingJob` for each complete visit
5. Switches to queue database to ensure proper job storage

**SQL Query Pattern:**
```sql
-- Switches database context for job enqueueing
USE solid_queue_dev_emr_api;
INSERT INTO solid_queue_jobs ...
```

#### 3. **StreamMissedVisitsJob (Scheduled)**

**Trigger:** Daily at 1 AM

**Purpose:** Identify and stream complete ART Module visits from patients who were expected but didn't show up.

**Logic:**
1. Query jobs created yesterday for **ART Module only** (program_id = 1)
2. Extract patient IDs from queued visits
3. Compare with actual visits from that day's encounters
4. Identify patients who were expected but didn't visit
5. Only enqueue **complete visits** for each missed visit

**Algorithm:**
```
missed_patients = expected_from_queued_jobs - actual_visits_today
stream_only_complete_visits(missed_patients)
```

**Note:** Only complete visits are streamed; incomplete visits remain in the system for completion.

#### 4. **ClearFinishedJob (Scheduled)**

**Trigger:** Daily at 1 AM

**Purpose:** Maintenance job that removes successfully finished job records to prevent table bloat

```ruby
SolidQueue::Job.clear_finished_in_batches
```

### Payload Structure

The data sent to CDR contains complete visit information with ART-specific analytical data:

```json
{
  "meta": {
    "program_id": 1,
    "ip_address": "192.168.1.100",
    "location_id": 123
  },
  "payload": {
    "raw": {
      "patient": {
        "id": 12345,
        "uuid": "550e8400-e29b-41d4-a716-446655440000",
        "person": {
          "id": 54321,
          "uuid": "550e8400-e29b-41d4-a716-446655440001",
          "names": [
            {
              "id": 1,
              "uuid": "550e8400-e29b-41d4-a716-446655440002",
              "given_name": "John",
              "middle_name": "Paul",
              "family_name": "Doe",
              "preferred": true
            }
          ],
          "addresses": [
            {
              "id": 1,
              "uuid": "550e8400-e29b-41d4-a716-446655440003",
              "address1": "123 Main Street",
              "address2": "Apartment 4B",
              "city_village": "Lilongwe",
              "state_province": "Central",
              "country": "Malawi",
              "postal_code": "00000"
            }
          ],
          "person_attributes": [
            {
              "id": 1,
              "person_attribute_type_id": 1,
              "value": "...",
              "type": "attribute_type_name"
            }
          ],
          "birthdate": "1985-05-15",
          "gender": "M",
          "dead": false
        },
        "patient_identifiers": [
          {
            "id": 1,
            "uuid": "550e8400-e29b-41d4-a716-446655440004",
            "identifier": "NP123456789",
            "identifier_type": "National Patient ID",
            "type": "National Patient ID",
            "location": "Central Hospital"
          },
          {
            "id": 2,
            "uuid": "550e8400-e29b-41d4-a716-446655440005",
            "identifier": "ART456789",
            "identifier_type": "ART Number",
            "type": "ART Number"
          }
        ],
        "relationships": [
          {
            "id": 1,
            "uuid": "550e8400-e29b-41d4-a716-446655440006",
            "relationship_type_id": 1,
            "person_b": { /* Related person details */ },
            "person_b_person": { /* Related person expanded */ }
          }
        ],
        "merge_history": [],
        "art_start_date": "2020-03-15"
      },
      "encounters": [
        {
          "id": 98765,
          "uuid": "550e8400-e29b-41d4-a716-446655440010",
          "encounter_type_id": 1,
          "encounter_datetime": "2024-02-19 10:30:00",
          "type": {
            "id": 1,
            "uuid": "550e8400-e29b-41d4-a716-446655440011",
            "name": "VITALS"
          },
          "patient": { /* Patient reference */ },
          "location": {
            "id": 123,
            "uuid": "550e8400-e29b-41d4-a716-446655440012",
            "name": "Central Hospital"
          },
          "provider": {
            "id": 456,
            "uuid": "550e8400-e29b-41d4-a716-446655440013",
            "identifier": "DOC001",
            "names": [
              {
                "id": 1,
                "uuid": "550e8400-e29b-41d4-a716-446655440014",
                "given_name": "Jane",
                "family_name": "Smith"
              }
            ]
          },
          "program": {
            "id": 1,
            "uuid": "550e8400-e29b-41d4-a716-446655440015",
            "name": "HIV PROGRAM"
          },
          "observations": [
            {
              "id": 11111,
              "uuid": "550e8400-e29b-41d4-a716-446655440016",
              "obs_id": 11111,
              "obs_group_id": null,
              "concept_id": 5089,
              "value_coded": 1065,
              "value_numeric": null,
              "value_text": null,
              "value_datetime": null,
              "concept": {
                "id": 5089,
                "uuid": "550e8400-e29b-41d4-a716-446655440017",
                "name": "HEIGHT",
                "concept_names": [
                  {
                    "id": 1,
                    "concept_id": 5089,
                    "name": "HEIGHT",
                    "locale": "en",
                    "locale_preferred": true
                  }
                ]
              },
              "drug": null
            },
            {
              "id": 11112,
              "uuid": "550e8400-e29b-41d4-a716-446655440018",
              "concept_id": 5090,
              "value_numeric": 170,
              "concept": {
                "id": 5090,
                "uuid": "550e8400-e29b-41d4-a716-446655440019",
                "name": "WEIGHT",
                "concept_names": [
                  {
                    "id": 2,
                    "concept_id": 5090,
                    "name": "WEIGHT",
                    "locale": "en",
                    "locale_preferred": true
                  }
                ]
              }
            }
          ],
          "orders": [
            {
              "id": 22222,
              "uuid": "550e8400-e29b-41d4-a716-446655440020",
              "order_type_id": 1,
              "concept_id": 307,
              "order_reason": "Routine monitoring",
              "instructions": "Fasting",
              "start_date": "2024-02-19",
              "auto_expire_date": "2024-03-20",
              "lims_acknowledgement_status": {
                "id": 1,
                "order_id": 22222,
                "status": "received",
                "created_at": "2024-02-19 10:31:00",
                "updated_at": "2024-02-19 10:31:00"
              },
              "drug_order": null
            },
            {
              "id": 22223,
              "uuid": "550e8400-e29b-41d4-a716-446655440021",
              "order_type_id": 2,
              "concept_id": 80085,
              "order_reason": "First line therapy",
              "instructions": "Twice daily with food",
              "start_date": "2024-02-15",
              "auto_expire_date": null,
              "lims_acknowledgement_status": null,
              "drug_order": {
                "id": 33333,
                "uuid": "550e8400-e29b-41d4-a716-446655440022",
                "drug_inventory_id": 2,
                "dose": 300,
                "dose_units": "mg",
                "frequency": "BD",
                "duration": null,
                "duration_units": "months",
                "quantity": 60,
                "quantity_units": "tablets",
                "drug": {
                  "id": 2,
                  "uuid": "550e8400-e29b-41d4-a716-446655440023",
                  "name": "Efavirenz",
                  "drug_cms": {
                    "id": 1,
                    "drug_id": 2,
                    "cms_id": "EFV-300mg"
                  }
                }
              }
            }
          ],
          "patient_id": 12345,
          "voided": false,
          "created_at": "2024-02-19 10:30:00"
        }
      ],
      "current_program": [
        {
          "id": 1,
          "uuid": "550e8400-e29b-41d4-a716-446655440030",
          "patient_id": 12345,
          "program_id": 1,
          "date_enrolled": "2020-03-15",
          "date_completed": null,
          "location_id": 123,
          "program": {
            "id": 1,
            "uuid": "550e8400-e29b-41d4-a716-446655440031",
            "name": "HIV PROGRAM"
          },
          "patient_states": [
            {
              "id": 1,
              "uuid": "550e8400-e29b-41d4-a716-446655440032",
              "patient_program_id": 1,
              "state_id": 7,
              "start_date": "2020-03-15",
              "end_date": null,
              "workflow_state": {
                "id": 7,
                "uuid": "550e8400-e29b-41d4-a716-446655440033",
                "name": "On antiretrovirals",
                "description": "Patient is currently on antiretroviral therapy"
              }
            }
          ]
        }
      ]
    },
    "analytical": {
      "art_initial": {
        "patient_id": 12345,
        "art_start_date": "2020-03-15",
        "baseline_cd4": 45,
        "baseline_vl": 450000,
        "baseline_who_stage": 3,
        "initial_regimen": "EFV+TDF+3TC",
        "enrollment_location": "Central Hospital"
      },
      "art_visit": {
        "patient_id": 12345,
        "visit_date": "2024-02-19",
        "visit_type": "ROUTINE",
        "cd4_count": 850,
        "viral_load": 45,
        "regimen": "TLD",
        "adherence_level": "GOOD",
        "clinical_stage": "1",
        "weight": 70.5,
        "height": 170,
        "bmi": 24.4,
        "blood_pressure_systolic": 120,
        "blood_pressure_diastolic": 80
      },
      "demographics": {
        "patient_id": 12345,
        "name": "John Paul Doe",
        "date_of_birth": "1985-05-15",
        "gender": "M",
        "age": 38,
        "phone_number": "+265991234567",
        "address": "123 Main Street, Lilongwe",
        "national_id": "NP123456789"
      },
      "outcomes": [
        {
          "patient_id": 12345,
          "status": "on_art",
          "days_on_art": 1400,
          "last_visit_date": "2024-02-19",
          "next_appointment_date": "2024-03-19",
          "viral_suppression": "suppressed",
          "last_cd4": 850,
          "last_vl": 45
        }
      ]
    }
  }
}
```

**Note:** Only **complete encounters** are included in the payload. The `analytical` section contains ART-specific data processing with pre-aggregated, clinical-grade information optimized for reporting and analytics.

### Payload Attributes by Section

#### Meta Section

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `program_id` | Integer | Always `1` for ART Module | `1` |
| `ip_address` | String | IPv4 private IP address of the server sending data | `192.168.1.100` |
| `location_id` | Integer | Current health center/facility location ID | `123` |

#### Patient Object Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | Integer | Patient database ID |
| `uuid` | String | Unique identifier (UUID v4) |
| `person` | Object | Person details including names, addresses, attributes |
| `patient_identifiers` | Array | All patient identifiers (NPID, ART Number, etc.) |
| `relationships` | Array | Patient relationships (contacts, guardians, etc.) |
| `merge_history` | Array | History of merged patient records |
| `art_start_date` | Date | Date patient started ART |

#### Encounter (Visit) Object Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | Integer | Encounter database ID |
| `uuid` | String | Unique identifier |
| `encounter_type_id` | Integer | Type of encounter (VITALS, CONSULTATION, etc.) |
| `encounter_datetime` | DateTime | Timestamp of the visit |
| `type` | Object | Encounter type details |
| `provider` | Object | Healthcare provider info (names, identifier) |
| `location` | Object | Health facility location |
| `observations` | Array | Clinical observations (vitals, assessments) |
| `orders` | Array | Orders placed (labs, medications) |

#### Observation Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | Integer | Observation ID |
| `uuid` | String | Unique identifier |
| `concept_id` | Integer | Concept being observed |
| `value_coded` | Integer | Coded value (for coded concepts) |
| `value_numeric` | Float | Numeric value (for numeric concepts) |
| `value_text` | String | Text value |
| `value_datetime` | DateTime | DateTime value |
| `concept` | Object | Concept details with names |

#### Order Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | Integer | Order ID |
| `uuid` | String | Unique identifier |
| `order_type_id` | Integer | Type (lab or drug) |
| `concept_id` | Integer | What is being ordered |
| `start_date` | Date | When order starts |
| `auto_expire_date` | Date | When order expires automatically |
| `lims_acknowledgement_status` | Object | Lab system acknowledgment status |
| `drug_order` | Object | Drug order details (dose, frequency, quantity) |

#### Analytical Data Attributes

**art_initial:**
- `art_start_date`: When patient started ART
- `baseline_cd4`: CD4 count at enrollment
- `baseline_vl`: Viral load at enrollment
- `baseline_who_stage`: WHO clinical stage at enrollment
- `initial_regimen`: First ART regimen prescribed

**art_visit:**
- `visit_date`: Date of the visit
- `cd4_count`: Current CD4 count
- `viral_load`: Current viral load
- `regimen`: Current ART regimen
- `adherence_level`: Patient adherence assessment
- `clinical_stage`: Current WHO clinical stage
- Vital signs: `weight`, `height`, `bmi`, `blood_pressure_*`

**demographics:**
- Patient name, DOB, gender, age
- Contact information and address
- National ID

**outcomes:**
- `status`: Treatment status (on_art, completed, lost_to_followup)
- `days_on_art`: Duration on treatment
- `viral_suppression`: Suppression status
- `last_visit_date`: Most recent visit
- `next_appointment_date`: Scheduled follow-up

### Payload Compression

All payloads are automatically compressed using gzip before transmission:

```ruby
to_compressed_json(payload) # Handles gzip compression
```

---

## Monitoring Jobs

### 1. Web Dashboard

Access the SolidQueue Monitor at:

```
http://your-server:3000/streaming
```

**Features:**
- Visual job queue status
- Job history and execution times
- Real-time worker information
- Process/dispatcher status
- Filtering and sorting capabilities

### 2. API Endpoints

#### Get Streaming Statistics

```bash
curl http://localhost:3000/api/v1/streaming/stats
```

**Response:**
```json
{
  "solid_queue": {
    "jobs_done": 1250,
    "jobs_failed": 3,
    "jobs_pending": 15,
    "jobs_queued": 0
  },
  "last_sync_at": "2024-02-19T14:35:22Z",
  "visits_since_last_sync": 42
}
```

**Metrics Explained:**
- `jobs_done`: Successfully completed jobs
- `jobs_failed`: Jobs that encountered errors
- `jobs_pending`: Jobs waiting to be processed
- `jobs_queued`: Jobs scheduled for future execution
- `last_sync_at`: Timestamp of last successful job completion
- `visits_since_last_sync`: New encounters since last sync

#### Get Failed Jobs

```bash
curl http://localhost:3000/api/v1/streaming/failed
```

**Response:**
```json
[
  {
    "id": 456,
    "job_id": 789,
    "error": "Failed to send stream data Connection refused",
    "created_at": "2024-02-19T10:30:00Z",
    "job": {
      "id": 789,
      "job_class": "StreamingJob",
      "arguments": [...],
      "scheduled_at": "2024-02-19T10:29:00Z"
    }
  }
]
```

### 3. Database Queries

#### Check Queue Job Count

```sql
USE solid_queue_dev_emr_api;

-- Total jobs in queue
SELECT COUNT(*) as total_jobs FROM solid_queue_jobs;

-- Jobs by status
SELECT 
  'Failed' as status, COUNT(*) as count FROM solid_queue_failed_executions
UNION ALL
SELECT 
  'Claimed' as status, COUNT(*) as count FROM solid_queue_claimed_executions
UNION ALL
SELECT 
  'Ready' as status, COUNT(*) as count FROM solid_queue_ready_executions
UNION ALL
SELECT 
  'Scheduled' as status, COUNT(*) as count FROM solid_queue_scheduled_executions
UNION ALL
SELECT 
  'Blocked' as status, COUNT(*) as count FROM solid_queue_blocked_executions;
```

**Note:** The SolidQueue implementation in this system does not use `solid_queue_finished_executions`. Completed jobs are tracked through the other execution tables above.

#### Check Active Workers

```sql
USE solid_queue_dev_emr_api;

SELECT 
  id,
  kind,
  hostname,
  pid,
  last_heartbeat_at,
  created_at
FROM solid_queue_processes
WHERE last_heartbeat_at > NOW() - INTERVAL 1 MINUTE;
```

#### Find Recently Completed Jobs

```sql
USE solid_queue_dev_emr_api;

-- View recent job executions and their status
SELECT 
  j.id,
  j.job_class,
  j.created_at,
  CASE 
    WHEN ce.id IS NOT NULL THEN 'Claimed'
    WHEN re.id IS NOT NULL THEN 'Ready'
    WHEN se.id IS NOT NULL THEN 'Scheduled'
    WHEN fe.id IS NOT NULL THEN 'Failed'
    WHEN be.id IS NOT NULL THEN 'Blocked'
    ELSE 'Unknown'
  END as status,
  COALESCE(ce.created_at, re.created_at, se.created_at, fe.created_at, be.created_at) as execution_time
FROM solid_queue_jobs j
LEFT JOIN solid_queue_claimed_executions ce ON j.id = ce.job_id
LEFT JOIN solid_queue_ready_executions re ON j.id = re.job_id
LEFT JOIN solid_queue_scheduled_executions se ON j.id = se.job_id
LEFT JOIN solid_queue_failed_executions fe ON j.id = fe.job_id
LEFT JOIN solid_queue_blocked_executions be ON j.id = be.job_id
ORDER BY j.created_at DESC
LIMIT 20;
```

### 4. Logs

Check Rails logs for streaming activity:

```bash
# View streaming logs
tail -f log/development.log | grep -i stream

# View with timestamps
dtail -f log/development.log | grep -E "StreamingJob|StreamingService"

# Count streaming operations
grep -c "Sending stream data" log/development.log
```

**Log Examples:**
```
[StreamingService] INFO: Sending stream data for John Doe on 2024-02-19 to http://cdr.example.com/api/v1/stream
[StreamingService] ERROR: Failed to send stream data Connection refused
[StreamingJob] INFO: Processing StreamingJob for patient 123, program 1, date 2024-02-19
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Streaming Setup Fails

**Symptom:** `rake streaming:setup` fails with database error

**Causes & Solutions:**

1. **Queue database config not found in database.yml**
   ```bash
   # Solution: Run the database setup script first
   bin/setup_streaming.sh development
   ```

2. **CDR configuration missing**
   ```bash
   # Solution: Add CDR config to application.yml
   vim config/application.yml
   # Add under cdr section:
   # cdr:
   #   url: http://cdr-server/api/v1/stream
   #   username: admin
   #   password: password
   ```

3. **MySQL permissions issue**
   ```bash
   # Solution: Verify MySQL user has CREATE DATABASE permission
   mysql -u root -p -e "GRANT ALL ON solid_queue_* TO 'user'@'localhost';"
   ```

#### Issue 2: Jobs Not Processing

**Symptom:** Jobs stuck in queue, not transitioning to finished state

**Diagnosis Steps:**

```bash
# 1. Check if workers are running
ps aux | grep "jobs exec"

# 2. Check queue database for active workers
mysql -u user -p database -e "SELECT * FROM solid_queue_processes WHERE last_heartbeat_at > NOW() - INTERVAL 5 MINUTE;"

# 3. Check if there are any claimed executions
mysql -u user -p database -e "SELECT COUNT(*) FROM solid_queue_claimed_executions;"
```

**Solutions:**

1. **Workers not running:**
   ```bash
   # Start workers in background
   bundle exec jobs exec > log/solid_queue.log 2>&1 &
   ```

2. **Workers crashed:**
   ```bash
   # Kill any stale processes
   pkill -f "jobs exec"
   
   # Clear stale workers from database
   mysql -u user -p database -e "DELETE FROM solid_queue_processes WHERE last_heartbeat_at < NOW() - INTERVAL 10 MINUTE;"
   
   # Restart workers
   bundle exec jobs exec > log/solid_queue.log 2>&1 &
   ```

3. **Database connection issue:**
   ```bash
   # Test queue database connection
   mysql -u user -p database solid_queue_dev_database -e "SELECT 1;"
   ```

#### Issue 3: Failed Jobs Accumulating

**Symptom:** `jobs_failed` count increasing, data not reaching CDR

**Diagnosis:**

```bash
# View failed job details
curl http://localhost:3000/api/v1/streaming/failed | jq '.[].job.arguments'

# Check for network connectivity to CDR
curl -v http://cdr-server.example.com/api/v1/stream

# Check CDR authentication
curl -u username:password http://cdr-server.example.com/api/v1/stream
```

**Common Failure Causes:**

1. **CDR endpoint unreachable:**
   ```yaml
   # Error: Failed to send stream data Connection refused
   
   # Solution: Verify CDR URL and network connectivity
   # In config/application.yml, check:
   cdr:
     url: http://correct-cdr-host.com/api/v1/stream  # Should be correct host
   ```

2. **Authentication failure:**
   ```yaml
   # Error: Failed to send stream data 401 Unauthorized
   
   # Solution: Verify credentials in config/application.yml
   cdr:
     username: correct_username
     password: correct_password
   ```

3. **Payload too large:**
   ```
   # Error: Failed to send stream data 413 Payload Too Large
   
   # Solution: Check patient data and consider archiving old encounters
   # Compression is automatic via to_compressed_json()
   ```

4. **Timeout:**
   ```
   # Error: Failed to send stream data Timeout
   
   # Solution: CDR is slow. Check CDR performance
   # Streaming service has 10-minute timeout (600 seconds) built in
   ```

#### Issue 4: Memory or CPU Issues

**Symptom:** High memory/CPU usage by workers, system degradation

**Solutions:**

1. **Reduce worker concurrency:**
   ```yaml
   # Edit config/queue.yml
   workers:
     - queues: "*"
       threads: 2        # Reduce from 3 to 2
       processes: 1      # Or reduce number of processes
       polling_interval: 0.1
   ```

2. **Adjust batch size:**
   ```yaml
   dispatchers:
     - polling_interval: 1
       batch_size: 250    # Reduce from 500 to 250
   ```

3. **Monitor resource usage:**
   ```bash
   # Watch worker resource consumption
   top -p $(pgrep -f "jobs exec" | tr '\n' ',')
   
   # Or use system monitoring tools
   iostat -x 1
   ```

#### Issue 5: Data Not Appearing in CDR

**Symptom:** Jobs show as successful but data missing from CDR

**Investigation:**

1. **Check if jobs are actually running:**
   ```bash
   # Monitor logs in real-time
   tail -f log/development.log | grep -E "StreamingService|Sending stream"
   ```

2. **Verify correct data is being sent:**
   ```ruby
   # In Rails console
   patient = Patient.find(123)
   service = StreamingService.new(patient_id: 123, program_id: 1, date: Date.today)
   # Check the payload (without actually sending)
   payload = service.instance_variable_get(:@payload)
   ```

3. **Check CDR logs:**
   - Request CDR team to check if they're receiving requests
   - Verify CDR is correctly processing the received data

#### Issue 6: Scheduled Jobs Not Running

**Symptom:** `StreamIncompleteVisitsJob` and `StreamMissedVisitsJob` not executing at 1 AM

**Diagnosis:**

```bash
# Check if recurring jobs are configured
cat config/recurring.yml

# Check solid_queue_scheduled_executions table
mysql -u user -p database -e "SELECT * FROM solid_queue_scheduled_executions WHERE scheduled_at > NOW();"

# Check if dispatcher is running
ps aux | grep "jobs exec" | grep -v grep
```

**Solutions:**

1. **Recurring jobs configuration missing:**
   ```bash
   # Verify config/recurring.yml exists and is properly formatted
   cat config/recurring.yml
   
   # Should contain:
   # stream_incomplete_visits:
   #   class: StreamIncompleteVisitsJob
   #   schedule: at 1am every day
   ```

2. **Dispatcher not running:**
   ```bash
   # Start dispatcher (usually bundled with workers)
   bundle exec jobs exec
   ```

3. **Wrong timezone:**
   ```bash
   # Check Rails timezone setting
   # In config/application.rb:
   config.time_zone = 'UTC'  # Adjust to your timezone
   
   # The schedule "at 1am" uses the configured timezone
   ```

#### Issue 7: Queue Database Growing Too Large

**Symptom:** `solid_queue_*` database growing unexpectedly, disk space issues

**Causes & Solutions:**

1. **`ClearFinishedJob` not running:**
   ```bash
   # Verify it's in recurring.yml
   grep -A 3 "clear_finished:" config/recurring.yml
   
   # Manually clear finished jobs
   mysql -u user -p database -e "DELETE FROM solid_queue_finished_executions WHERE created_at < NOW() - INTERVAL 30 DAY;"
   ```

2. **Failed jobs accumulating:**
   ```bash
   # Check failed jobs count
   mysql -u user -p database -e "SELECT COUNT(*) FROM solid_queue_failed_executions;"
   
   # Archive old failed jobs
   mysql -u user -p database -e "DELETE FROM solid_queue_failed_executions WHERE created_at < NOW() - INTERVAL 90 DAY;"
   ```

3. **Job arguments too large:**
   ```bash
   # Find jobs with large arguments
   mysql -u user -p database -e "SELECT id, job_class, LENGTH(arguments) as arg_size FROM solid_queue_jobs ORDER BY arg_size DESC LIMIT 10;"
   ```

---

## API Endpoints

### Streaming Statistics Endpoint

**GET** `/api/v1/streaming/stats`

Returns comprehensive queue and synchronization statistics.

**Response Fields:**
```json
{
  "solid_queue": {
    "jobs_done": number,        // Completed jobs
    "jobs_failed": number,      // Failed jobs requiring attention
    "jobs_pending": number,     // Jobs being processed
    "jobs_queued": number       // Scheduled jobs not yet ready
  },
  "last_sync_at": "ISO8601",   // Last job completion time
  "visits_since_last_sync": number  // New encounters since last sync
}
```

**Example Usage:**
```bash
curl -X GET http://localhost:3000/api/v1/streaming/stats | jq '.'
```

**Monitoring Alerts:**
- If `jobs_failed` > 0: Investigate failed jobs endpoint
- If `jobs_pending` > 1000: Workers may be overloaded
- If `last_sync_at` is older than expected: Jobs may be stuck

### Failed Jobs Endpoint

**GET** `/api/v1/streaming/failed`

Returns detailed information about failed jobs.

**Response Format:**
```json
[
  {
    "id": number,              // Failed execution ID
    "job_id": number,          // Original job ID
    "error": "string",         // Error message
    "created_at": "ISO8601",   // When it failed
    "job": {
      "id": number,
      "job_class": "string",   // Job class name
      "arguments": array,      // Job arguments (patient_id, program_id, date)
      "scheduled_at": "ISO8601"
    }
  }
]
```

**Example Usage:**
```bash
# Get all failed jobs
curl -X GET http://localhost:3000/api/v1/streaming/failed | jq '.'

# Count failed jobs
curl -X GET http://localhost:3000/api/v1/streaming/failed | jq 'length'

# Find failures from specific date
curl -X GET http://localhost:3000/api/v1/streaming/failed | \
  jq '.[] | select(.created_at | startswith("2024-02-19"))'
```

### Web Dashboard

**GET** `/streaming`

Provides a visual dashboard for monitoring queue status, workers, and job history.

**Features:**
- Real-time job counts
- Worker status and processes
- Job history and timeline
- Error investigation tools
- Search and filtering

---

## Configuration Reference

### application.yml

**CDR Configuration:**
```yaml
cdr:
  url: http://cdr.example.com/api/v1/stream
  username: api_username
  password: api_password
```

### database.yml

**Queue Database Configuration:**
```yaml
development: &dev
  primary:
    <<: *default
    database: bht_emr_dev
  queue:
    <<: *default
    database: solid_queue_dev_bht_emr
    migrations_paths: []
    processing_delay_time: 20

production:
  primary:
    <<: *default
    database: bht_emr_prod
  queue:
    <<: *default
    database: solid_queue_prod_bht_emr
    migrations_paths: db/queue_migrate
    processing_delay_time: 20
```

### queue.yml

**Worker Configuration:**
```yaml
default: &default
  dispatchers:
    - polling_interval: 1          # Check for jobs every 1 second
      batch_size: 500              # Fetch 500 jobs at a time
  workers:
    - queues: "*"                  # Process all queues
      threads: 3                   # Number of threads per process
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>  # Number of processes
      polling_interval: 0.1        # Check for job availability every 0.1 seconds

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

**Environment Variables:**
- `JOB_CONCURRENCY`: Number of worker processes (default: 1)
  ```bash
  JOB_CONCURRENCY=4 bundle exec jobs exec  # Start 4 worker processes
  ```

### recurring.yml

**Scheduled Jobs Configuration:**
```yaml
default: &default
  stream_incomplete_visits:
    class: StreamIncompleteVisitsJob
    queue: incomplete_visits
    schedule: at 1am every day
    priority: 1

  stream_missed_visits:
    class: StreamMissedVisitsJob
    queue: finished
    schedule: at 1am every day
    priority: 10

  clear_finished:
    class: ClearFinishedJob
    queue: finished
    schedule: at 1am every day
    priority: 10

development:
  <<: *default

production:
  <<: *default
```

### solid_queue.rb Initializer

**Logging Configuration:**
```ruby
module SilenceHeartbeat
  def heartbeat
    ActiveRecord::Base.logger.silence do
      restore_attributes
      with_lock { touch(:last_heartbeat_at) }
    end
  end
end

Rails.application.config.to_prepare do
  SolidQueue::Process.prepend(SilenceHeartbeat) unless Rails.env.production?
end
```

This silences verbose heartbeat logs in non-production environments.

### solid_queue_monitor.rb Initializer

**Web Dashboard Configuration:**
```ruby
SolidQueueMonitor.setup do |config|
  config.authentication_enabled = false      # Enable HTTP Basic Auth if needed
  # config.username = 'admin'
  # config.password = 'password'
  # config.jobs_per_page = 25
end
```

---

## Advanced Topics

### Manual Job Enqueueing

Stream a specific patient's visit:

```ruby
# In Rails console
patient_id = 123
program_id = 1
date = Date.today - 1

StreamingJob.perform_later(
  patient_id: patient_id,
  program_id: program_id,
  date: date.strftime('%Y-%m-%d')
)
```

### Bulk Streaming

Stream multiple patients:

```ruby
patient_ids = [1, 2, 3, 4, 5]
program_id = 1
date = Date.today - 1

patient_ids.each do |patient_id|
  StreamingJob.perform_later(
    patient_id: patient_id,
    program_id: program_id,
    date: date.strftime('%Y-%m-%d')
  )
end
```

### Retry Failed Jobs

Manually requeue failed jobs:

```ruby
# In Rails console
# Establish queue database connection
ActiveRecord::Base.establish_connection(:queue)

failed_executions = SolidQueue::FailedExecution.all
failed_executions.each do |execution|
  job = execution.job
  StreamingJob.perform_later(
    patient_id: job.arguments[0]['patient_id'],
    program_id: job.arguments[0]['program_id'],
    date: job.arguments[0]['date']
  )
end

ActiveRecord::Base.establish_connection(:primary)
```

### Performance Tuning

1. **Increase worker concurrency for high-volume streaming:**
   ```bash
   JOB_CONCURRENCY=8 bundle exec jobs exec
   ```

2. **Increase dispatcher batch size to handle more jobs:**
   ```yaml
   # config/queue.yml
   batch_size: 1000
   ```

3. **Reduce polling intervals for faster job pickup:**
   ```yaml
   # config/queue.yml
   dispatchers:
     - polling_interval: 0.5    # Check more frequently
   workers:
     - polling_interval: 0.05   # Faster availability checks
   ```

---

## Support and Contact

For issues or questions regarding the streaming system:

1. Check this documentation first
2. Review the troubleshooting section
3. Consult application and queue logs
4. Contact the development team with relevant error logs and timestamps

---

**Last Updated:** February 2024
**Version:** 1.0
