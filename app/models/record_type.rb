# frozen_string_literal: true

class RecordType < ApplicationRecord
  has_many :record_sync_statuses
end
