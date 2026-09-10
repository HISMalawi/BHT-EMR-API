# Streaming Ledger and Phase 3 Replay/Acknowledgement Design

## Overview

The streaming ledger is the business source of truth for outbound patient/program/day stream records. It records each logical stream bundle and tracks whether it was queued, sent, acknowledged by the receiving API, failed, or scheduled for replay.

This ledger is the mechanism that makes the streaming pipeline auditable and recoverable.

## Why a ledger is needed

The streaming system does not just enqueue jobs in SolidQueue. It also needs to know whether a logical stream was actually transmitted and whether the receiving system accepted it.

Without a ledger, the app only has queue state, which is not the same thing as business truth:

- SolidQueue tells us a job exists or failed in the queue layer.
- The ledger tells us whether a patient/program/date stream was actually sent and accepted.
- The ledger allows replay of missed or failed streams.

## Stream identity

Each ledger row represents one logical stream bundle.

The unique identity is the stream key:

```ruby
"location_id:patient_id:program_id:stream_date"
```

Example:

```ruby
"12:42:7:2026-09-10"
```

This key is intentionally not just the patient/program/date alone. It also includes the location so two facilities do not collide on the same stream identity.

## Migration schema

The migration creates the ledger table and indexes the fields needed for lookup and replay:

- `uuid` unique identity for the row
- `stream_key` unique business key per stream bundle
- `patient_id`
- `program_id`
- `stream_date`
- `payload_hash`
- `status`
- `response_code`
- `error_message`
- `sent_at`
- `acknowledged_at`
- `retry_count`
- `created_at`, `updated_at`

Indexes cover:

- unique `uuid`
- unique `stream_key`
- patient/program/date lookup
- status filtering

## Ledger states

The ledger status enum is:

- `queued`
- `sent`
- `acknowledged`
- `failed`
- `retrying`

These states represent the lifecycle of a logical stream bundle.

## Lifecycle

### 1. Queued

When a stream job is triggered, the app creates or finds a ledger row for the stream key and marks it as `queued`.

This is done in the job layer before the outbound request is attempted.

### 2. Sent

When the request is made to the downstream CDR endpoint, the service marks the record as `sent` and stores:

- payload hash
- response code if available
- sent timestamp

### 3. Acknowledged

If the receiving API confirms the stream was successfully saved, the app marks the ledger as `acknowledged` and stores the acknowledgement timestamp and response code.

This is the successful end state for a stream.

### 4. Failed

If the network call fails or the remote service rejects the stream, the ledger is marked as `failed`, preserving the error message and response code. The retry counter is incremented.

### 5. Retrying / replay

Rows in `queued`, `failed`, or `retrying` are eligible for replay. A retry marks the record as `retrying` and increments the retry counter before the job is re-enqueued.

This is how the system recovers from temporary failures without reprocessing every stream in the system.

## Service responsibilities

### StreamingLedgerService

This service owns the state transitions and lookup logic:

- `find_or_create!`
- `mark_queued!`
- `mark_sent!`
- `mark_acknowledged!`
- `mark_failed!`
- `mark_retrying!`
- `find_by_stream_key`
- `query`
- `replayable_streams`
- `build_stream_key`

### StreamingService

The transport layer builds the outbound payload and sends it to the downstream service. It updates the ledger as the request progresses:

- before send: may mark queued
- after send: mark sent
- after response: mark acknowledged
- on exception: mark failed

## API contract

### GET /api/v1/streaming/ledgers

Returns filtered ledger records.

Supported filters:

- `status`
- `start_date`
- `end_date`
- `patient_id`
- `program_id`
- `stream_key`

Examples:

```http
GET /api/v1/streaming/ledgers?status=failed
GET /api/v1/streaming/ledgers?status=queued,failed
GET /api/v1/streaming/ledgers?start_date=2026-09-01&end_date=2026-09-10
GET /api/v1/streaming/ledgers?patient_id=42&program_id=1
GET /api/v1/streaming/ledgers?stream_key=12:42:7:2026-09-10
```

### POST /api/v1/streaming/ack

Marks a ledger record as acknowledged.

Request example:

```json
{
  "stream_key": "12:42:7:2026-09-10",
  "response_code": 202
}
```

### POST /api/v1/streaming/replay

Re-enqueues ledger records that are not yet acknowledged.

Request examples:

```http
POST /api/v1/streaming/replay
```

or

```http
POST /api/v1/streaming/replay?stream_key=12:42:7:2026-09-10
```

## Replay behavior

Replay targets the logical stream bundle, not individual encounter rows. If the stream bundle for a patient/program/date is incomplete or failed, that bundle is retried as one unit.

This is the correct granularity because the outbound payload is built as a patient-level bundle for a given date.

## Why this is better than queue-only monitoring

Queue metrics answer:

- did a job get enqueued?
- did it fail in the queue adapter?
- is it still pending?

Ledger state answers:

- which patient/program/date entries were actually sent?
- which were accepted by the receiver?
- which failed and need replay?
- which bundles are still incomplete from a business perspective?

This is the difference between infrastructure visibility and business reconciliation.

## Operational guidance

Use the ledger heavily for:

- audit checks
- replay of failed sends
- verifying receiver acceptance
- checking whether a given patient/program/date was already processed in a facility

Use SolidQueue only for transport-level execution health and job monitoring.

## Summary

Phase 3 adds the missing reliability layer:

- stream identity via `stream_key`
- persistent ledger record
- send/ack/fail lifecycle
- replayable failed or queued records
- query API for filtering by date and status

This turns the streaming system from a fire-and-forget queue into a recoverable, auditable data synchronization pipeline.
