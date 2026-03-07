# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AncService::DashboardStatsQueries do
  let(:date) { Date.today }
  let(:queries) { described_class.new(date) }

  describe '#new_and_continuing_anc_clients' do
    it 'returns an integer' do
      expect(queries.new_and_continuing_anc_clients).to be_a(Integer)
    end

    it 'returns zero or positive count' do
      expect(queries.new_and_continuing_anc_clients).to be >= 0
    end

  end
end
