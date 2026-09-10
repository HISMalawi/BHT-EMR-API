# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StreamingLedgerService do
  before(:each) do
    StreamingLedger.delete_all
  end

  let(:patient_id) { 42 }
  let(:program_id) { 7 }
  let(:stream_date) { Date.new(2026, 9, 10) }
  let(:location_id) { 12 }
  let(:stream_key) { '12:42:7:2026-09-10' }

  describe '.build_stream_key' do
    it 'combines the location, patient, program and date into a unique stream key' do
      expect(described_class.build_stream_key(patient_id, program_id, stream_date, location_id)).to eq(stream_key)
    end
  end

  describe '.find_or_create!' do
    it 'creates a queued ledger using the location-aware stream key' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      expect(ledger).to be_persisted
      expect(ledger.status).to eq('queued')
      expect(ledger.stream_key).to eq(stream_key)
      expect(StreamingLedger.column_names).not_to include('location_id')
    end

    it 'is idempotent for the same patient, program, date and location' do
      first_ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                                   stream_date: stream_date, location_id: location_id)
      second_ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                                    stream_date: stream_date, location_id: location_id)

      expect(first_ledger.id).to eq(second_ledger.id)
      expect(StreamingLedger.where(stream_key: stream_key).count).to eq(1)
    end
  end

  describe 'status lifecycle' do
    it 'updates the ledger from queued to sent to acknowledged and finally failed' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      described_class.mark_sent!(ledger, response_code: 200, payload_hash: 'abc123')
      expect(ledger.reload.status).to eq('sent')
      expect(ledger.payload_hash).to eq('abc123')
      expect(ledger.response_code).to eq(200)

      described_class.mark_acknowledged!(ledger, response_code: 202)
      expect(ledger.reload.status).to eq('acknowledged')
      expect(ledger.response_code).to eq(202)

      described_class.mark_failed!(ledger, error_message: 'timeout', response_code: 500)
      expect(ledger.reload.status).to eq('failed')
      expect(ledger.retry_count).to eq(1)
      expect(ledger.error_message).to eq('timeout')
    end

    it 'marks a ledger as retrying for replay and tracks retry count' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)

      described_class.mark_retrying!(ledger)

      expect(ledger.reload.status).to eq('retrying')
      expect(ledger.retry_count).to eq(1)
      expect(described_class.replayable_streams.where(stream_key: stream_key)).to exist
    end
  end

  describe '.query' do
    it 'filters ledgers by status and date range' do
      ledger = described_class.find_or_create!(patient_id: patient_id, program_id: program_id,
                                              stream_date: stream_date, location_id: location_id)
      described_class.mark_failed!(ledger, error_message: 'timeout', response_code: 500)

      results = described_class.query(status: 'failed', start_date: stream_date, end_date: stream_date)

      expect(results.where(stream_key: stream_key)).to exist
      expect(results.where(patient_id: patient_id, program_id: program_id)).to exist
    end
  end
end
