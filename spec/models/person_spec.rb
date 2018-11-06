# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Person, type: :model do
  describe :birthdate do
    it 'can not be less than TimeUtils.epoch_date' do
      person = create :person
      person.birthdate = TimeUtils.date_epoch - 1.days

      expect(person.save).to be false
      expect(person.errors.size).to be 1
      expect(person.errors).to include :birthdate
    end

    it 'can not be greater than today' do
      person = create :person
      person.birthdate = Date.today + 1.days

      expect(person.save).to be false
      expect(person.errors.size).to be 1
      expect(person.errors).to include :birthdate
    end

    it 'can be equal to epoch_date' do
      person = create :person
      person.birthdate = TimeUtils.date_epoch

      expect(person.save).to be true
    end

    it 'can be equal to today' do
      person = create :person
      person.birthdate = Date.today

      expect(person.save).to be true
    end
  end
end
