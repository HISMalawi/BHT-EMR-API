# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppointmentService do
  MINUTE = 60

  let(:patient) { create :patient }
  let(:epoch) { Date.today }
  let(:appointment_service) { AppointmentService.new retro_date: epoch }
  let(:person) { create :person }

  describe :appointments do
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

  describe :create_appointment do
    it 'uses existing appointment encounter for new appointments' do
      encounter = create :encounter_appointment, encounter_datetime: epoch,
                                                 patient: patient
      created = appointment_service.create_appointment patient, epoch
      expect(created.encounter).to eq(encounter)
    end

    it 'creates appointment encounter if one on given date does not exist' do
      get_appointment_encounter = proc do
        Encounter.where(
          type: encounter_type('Appointment'), patient: patient
        ).where(
          'DATE(encounter_datetime) = DATE(?)', epoch
        )[0]
      end

      expect(get_appointment_encounter.call).to be_nil

      appointment_service.create_appointment patient, epoch
      encounter = get_appointment_encounter.call
      expect(encounter.encounter_datetime.to_date).to eq(epoch)
    end

    it 'creates appointment for given date and patient' do
      (1...10).each do |dt|
        appointment_date = epoch + dt.days
        created = appointment_service.create_appointment patient, appointment_date
        expect(created.person).to be(patient.person)
        expect(created.value_datetime.to_date).to eq(appointment_date)
      end
    end

    it 'creates appointment on bound retro date' do
      created = appointment_service.create_appointment patient, epoch + 10.days
      retrieved = Observation.where concept: concept('Appointment date')

      expect(retrieved.size).to be(1)
      expect(created.value_datetime).to be(created.value_datetime)

      retro_date = created.encounter.encounter_datetime.to_date
      expect((epoch - retro_date).abs).to be < MINUTE
    end

    it 'can not create if given date is before bound date' do
      create_routine = proc do
        appointment_service.create_appointment patient, epoch - 1.day
      end

      expect(&create_routine).to raise_error(ArgumentError)
    end
  end

  describe :next_appointment do
    it 'selects shortest expiry date among available drug orders' do
    end
  end
end
