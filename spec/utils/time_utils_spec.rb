# frozen_string_literal = true

require 'rails_helper'
require 'time_utils'

RSpec.describe TimeUtils do
  describe '#calculate age' do
    it 'should be able to calculate a person\s age' do
      birthdate = 25.years.ago
      expected = ((Time.zone.now - birthdate.to_time) / 1.year.seconds).floor
      expect(TimeUtils.get_person_age(birthdate: birthdate)).to eq(expected)
    end
  end
end