# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArtService::AppointmentEngine do
  MINUTE = 60

  subject { ArtService::AppointmentEngine }

  let(:patient) { create :patient }
  let(:program) { Program.find_by_name('HIV Program') }
  let(:epoch) { Date.today }
  let(:person) { create :person }
  let(:appointment_service) { subject.new(retro_date: epoch, program: program, patient: patient) }

  describe :next_appointment do
    it 'does not suggest appointments on clinic days' do
      epoch = Date.strptime '2018-10-23' # Was a tuesday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      drug = Drug.arv_drugs[0]

      order = create :order, auto_expire_date: epoch,
                             start_date: epoch,
                             patient: patient,
                             concept: drug.concept,
                             encounter: treatment_encounter

      create :drug_order, order: order, drug: drug

      # Expecting a 4 day backward shift as the conventional 2 lands on
      # a sunday which is a default non-clinic day. Saturday too is skipped
      # as it is another non-clinic day.
      expected_date = (epoch - 4.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end

    it 'adjusts shortest expiry date back by 2 days' do
      epoch = Date.strptime '2018-10-26' # Was a friday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      drug = Drug.arv_drugs[0]

      order = create :order, auto_expire_date: epoch,
                             start_date: epoch,
                             patient: patient,
                             concept: drug.concept,
                             encounter: treatment_encounter

      create :drug_order, order: order, drug: drug

      expected_date = (epoch - 2.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end

    it 'selects shortest expiry date among available drug orders' do
      epoch = Date.strptime '2018-10-24' # Was a wednesday...

      treatment_encounter = create :encounter_treatment, patient: patient,
                                                         encounter_datetime: epoch,
                                                         program: program
      arv_drugs = Drug.arv_drugs

      (0...5).collect do |i|
        drug = arv_drugs[i]
        order = create :order, auto_expire_date: epoch + i.days,
                               start_date: epoch,
                               patient: patient,
                               concept: drug.concept,
                               encounter: treatment_encounter

        create :drug_order, order: order, drug: drug
      end

      # Expecting a 2 day backward shift from our epoch must be our shortest
      # expiry date
      expected_date = (epoch - 2.days).to_date

      engine = subject.new program: program, patient: patient, retro_date: epoch
      date = engine.next_appointment_date[:appointment_date]
      expect(date).to eq(expected_date)
    end
  end

  describe :appointments do
    it 'retrieves all appointments' do
      create :concept_datatype
      create :concept
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (1..10).collect do |i|
        create :obs_appointment, encounter: encounter,
                                 value_datetime: epoch + i.days,
                                 person: person
      end

      retrieved = appointment_service.appointments.collect(&:obs_id).sort
      expect(retrieved).to eq(created.collect(&:obs_id).sort)
    end

    it 'retrieves all appointments for a given date' do
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (1..10).collect do |i|
        create :obs_appointment, encounter: encounter,
                                 value_datetime: epoch + i.days,
                                 person: person
      end

      retrieved = appointment_service.appointments value_datetime: epoch + 2.days
      expect(retrieved.size).to be(1)
      expect(retrieved[0].obs_id).to eq(created[1].obs_id)
    end

    it 'retrieves all appointments for a given person' do
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (1..10).collect do |i|
        create :obs_appointment, encounter: encounter,
                                 value_datetime: epoch + i.days
      end

      retrieved = appointment_service.appointments person: created[0].person
      expect(retrieved.size).to be(1)
      expect(retrieved[0].obs_id).to eq(created[0].obs_id)
    end

    it 'retrieves all appointments for a given date and person' do
      encounter = create :encounter_appointment, encounter_datetime: epoch

      created = (0..9).collect do |i|
        params = { encounter: encounter, value_datetime: epoch + i.days }
        params[:person] = person if i.odd?
        create :obs_appointment, params
      end

      # Odd numbered appointments in created belong to our `person`
      retrieved = appointment_service.appointments person: created[1].person,
                                                   value_datetime: created[1].value_datetime.to_date
      expect(retrieved.size).to be(1)
      expect(retrieved[0].person_id).to eq(created[1].person_id)
      expect(retrieved[0].obs_id).to eq(created[1].obs_id)
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
end
