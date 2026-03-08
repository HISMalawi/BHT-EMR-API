# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MnhService::AncStatsQueries do
  let(:queries) { described_class.new }

  describe '#new_and_continuing_anc_clients' do
    it 'returns an integer' do
      expect(queries.new_and_continuing_anc_clients).to be_a(Integer)
    end

    it 'returns zero or positive count' do
      expect(queries.new_and_continuing_anc_clients).to be >= 0
    end
  end

  describe '#stats_hash' do
    it 'returns a hash with expected ANC stat keys' do
      result = queries.stats_hash
      expect(result).to be_a(Hash)
      expect(result).to include(
        :new_and_continuing_anc_clients,
        :women_with_ultrasound_scanning,
        :proportion_women_ultrasound_scanning,
        :women_with_4_plus_anc_contacts,
        :percentage_women_4_plus_anc_contacts
      )
    end
  end
end
