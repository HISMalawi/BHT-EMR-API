# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ARTService::RegimenEngine do
  let(:regimen_service) { ARTService::RegimenEngine.new program: program('HIV Program') }

  describe :find_regimens do
    it 'raises ArgumentError if weight and age are not provided' do
      (expect { regimen_service.find_regimens }).to raise_error(ArgumentError)
    end

    it 'retrieves paed. regimens only for weights < 6' do
      regimens = regimen_service.find_regimens patient_weight: 5.9,
                                               patient_age: 3,
                                               patient_gender: 'M'

      expect(regimens.size).to eq(3)

      expect(lambda {
        regimens.each do |regimen, _drugs|
          # TODO: This ought to be expanded to check if the correct drugs are
          # being returned for each regimen
          break false unless regimen =~ /^[029]{1}P$/i
        end
      }.call).not_to be false
    end

    it 'retrieves regimens up to 12A for women under 45 years' do
      regimens = regimen_service.find_regimens patient_age: 30,
                                               patient_weight: 50,
                                               patient_gender: 'F'

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens up to 15A for women above 45 years' do
      regimens = regimen_service.find_regimens patient_age: 45,
                                               patient_weight: 50,
                                               patient_gender: 'F'

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens [0A 2A 4A 9A 11A] for women under 30 kilos' do
      regimens = regimen_service.find_regimens patient_age: 30,
                                               patient_weight: 29,
                                               patient_gender: 'F'

      expected_regimens = %w[0A 2A 4A 9A 11A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens below 12A for women below 35 years and between at least 35 kilos' do
      regimens = regimen_service.find_regimens patient_age: 30,
                                               patient_weight: 35,
                                               patient_gender: 'F'

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves regimens [0A 2A 4A 9A 11A] for men under 30 kilos' do
      regimens = regimen_service.find_regimens patient_age: 30,
                                               patient_weight: 29,
                                               patient_gender: 'M'

      expected_regimens = %w[0A 2A 4A 9A 11A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end

    it 'retrieves all regimens for men at least 35 kilos' do
      regimens = regimen_service.find_regimens patient_age: 30,
                                               patient_weight: 35,
                                               patient_gender: 'M'

      expected_regimens = %w[0A 2A 4A 5A 6A 7A 8A 9A 10A 11A 12A 13A 14A 15A]

      expect(regimens.size).to be expected_regimens.size
      regimens.keys.each { |k| expect(expected_regimens).to include k }
    end
  end
end
