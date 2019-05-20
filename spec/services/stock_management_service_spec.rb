# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StockManagementService do
  let(:service) { StockManagementService.new }
  let(:batch_number) { '1234567890xyz' }
  let(:stock_item) { { drug_id: Drug.last.id, quantity: 10, delivery_date: Date.today, expiry_date: 1.year.after } }

  describe :add_items_to_batch do
    it 'creates batch if batch does not exist' do
      expect(PharmacyBatch.all).to be_empty

      stock_items = (1...10).map { stock_item }
      service.add_items_to_batch('1234567890', stock_items)

      batches = PharmacyBatch.all
      expect(batches.size).to eq(1)
    end

    it 'does not create new batch if one already exists' do
      service.add_items_to_batch('1234567890', [])

      batches = PharmacyBatch.all
      expect(batches.size).to eq(1)
      expect(batches.first.items).to be_empty

      service.add_items_to_batch('1234567890', [stock_item])

      batches = PharmacyBatch.all
      expect(batches.size).to eq(1)
      expect(batches.first.items.size).to eq(1)
    end

    it 'adds given items to batch' do
      expect(PharmacyBatchItem.all).to be_empty

      service.add_items_to_batch('1234567890', [stock_item, stock_item])

      expect(PharmacyBatchItem.all.size).to be(2)
    end
  end

  describe :void_batch do
    it 'sets void reason on batch' do
      batch_number = '1234567890'
      service.add_items_to_batch(batch_number, [])
      expect(PharmacyBatch.find_by_batch_number(batch_number)).not_to be_nil

      service.void_batch(batch_number, 'Foobar')
      expect(PharmacyBatch.find_by_batch_number(batch_number)).to be_nil
      expect(PharmacyBatch.unscoped.find_by_batch_number(batch_number).void_reason).to eq('Foobar')
    end

    it 'voids batch items' do
      service.add_items_to_batch('1234567890', [stock_item] * 5)
      service.add_items_to_batch('9876543210', [stock_item] * 5)

      expect(PharmacyBatchItem.all.size).to eq(10)

      service.void_batch('1234567890', 'Hasta la Vista, Baby')
      expect(PharmacyBatchItem.all.size).to eq(5)
      expect(PharmacyBatchItem.unscoped.find_by_voided(1).void_reason).to eq('Hasta la Vista, Baby')
    end
  end
end
