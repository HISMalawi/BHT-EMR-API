# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppointmentService do
  let(:patient) { create :patient }
  let(:appointment_service) { AppointmentService.new retro_date: Time.now }
  let(:person) { create :person }
  let(:epoch) { Time.now }

  describe 'appointments' do
    it 'retrieves all appointments' do
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (1..10).collect do |i|
        create :obs_appointment, encounter: encounter,
                                 obs_datetime: epoch + i.days,
                                 person: person
      end

      retrieved = appointment_service.appointments.collect(&:obs_id).sort
      expect(retrieved).to eq(created.collect(&:obs_id).sort)
    end

    it 'retrieves all appointments for a given date' do
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (1..10).collect do |i|
        create :obs_appointment, encounter: encounter,
                                 obs_datetime: epoch + i.days,
                                 person: person
      end

      retrieved = appointment_service.appointments obs_datetime: epoch + 2.days
      expect(retrieved.size).to be(1)
      expect(retrieved[0].obs_id).to eq(created[1].obs_id)
    end

    it 'retrieves all appointments for a given person' do
    end

    it 'retrieves all appointments for a given date and person' do
    end
  end

  describe 'create_appointment' do
    it 'creates encounter if one is by date for each appointment' do
    end

    it 'creates appointment for given date and patient' do
    end

    it 'creates appointment on bound date' do
    end

    it 'can not create if given date is before bound date' do
    end
  end

  describe 'next_appointment' do
    it 'selects shortest expiry date among available drug orders' do
    end
  end
end
