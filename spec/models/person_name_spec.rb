# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersonName, type: :model do
  describe :given_name do
    it 'must not be less than 2 characters long' do
      name = create :person_name
      name.given_name = 'a'
      expect(name.save).to be false
      expect(name.errors.size).to eq 1
      expect(name.errors).to include :given_name
    end

    it 'can not be nil' do
      name = create :person_name
      name.given_name = nil
      expect(name.save).to be false
      expect(name.errors.size).to eq 1
      expect(name.errors).to include :given_name
    end
  end

  describe :family_name do
    it 'must not be less than 2 characters long' do
      name = create :person_name
      name.family_name = 'a'
      expect(name.save).to be false
      expect(name.errors.size).to eq 1
      expect(name.errors).to include :family_name
    end

    it 'can not be nil' do
      name = create :person_name
      name.family_name = nil
      expect(name.save).to be false
      expect(name.errors.size).to eq 1
      expect(name.errors).to include :family_name
    end
  end

  describe :middle_name do
    it 'can be nil' do
      name = create :person_name
      name.middle_name = nil
      expect(name.save).to be true
    end
  end
end
