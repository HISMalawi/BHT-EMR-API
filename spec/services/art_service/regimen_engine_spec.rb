# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ARTService::RegimenEngine do
  let(:regimen_service) { ARTService::RegimenEngine.new program: program('HIV Program') }

  describe :find_regimens do
    it 'raises ArgumentError if weight and age are not provided' do
      (expect { regimen_service.find_regimens }).to raise_error(ArgumentError)
    end

    it 'retrieves paed. regimens only for weights < 6' do
      regimens = regimen_service.find_regimens weight: 5.9

      expect(regimens.size).to eq(3)

      expect(lambda {
        regimens.each do |regimen, _drugs|
          # TODO: This ought to be expanded to check if the correct drugs are
          # being returned for each regimen
          break false unless regimen =~ /^[029]{1}P$/i
        end
      }.call).not_to be false
    end

    it 'retrieves regimens by age' do
      regimens = regimen_service.find_regimens age: 45

      expect(regimens.size).to eq(1)

      expect(regimens.keys.collect(&:upcase)).to include '13A'
    end
  end
end
