# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservationService do
  subject { ObservationService }
  let(:encounter) { create(:encounter) }
  let(:obs_params) do
    {
      concept_id: create(:concept).concept_id,
      obs_datetime: Time.now,
      value_text: 'Foobar'
    }
  end
  let(:create_observation) { ->(params) { subject.create_observation(encounter, params)} }

  describe :create_observation do
    it 'raises InvalidParameterError when not value field(s) is(are) present' do
      obs_params.delete(:value_text)

      expect(-> { create_observation.call(obs_params) })
        .to raise_exception(InvalidParameterError, /Empty observation:.*/)
    end

    it 'raises InvalidParameterError when invalid parameters are specified' do
      obs_params[:concept_id] = nil

      expect(-> { create_observation.call(obs_params) })
        .to raise_exception(InvalidParameterError, 'Could not create/update observation')
    end

    it 'creates observation given valid parameters' do
      obs = create_observation.call(obs_params)[0]
      expect(obs.id).not_to be_nil
      expect(obs.encounter_id).to eq(encounter.id)
      obs_params.each { |param, value| expect(obs.send(param)).to eq(value) }
    end

    it 'creates parent and child observations' do
      obs_params[:child] = obs_params.dup
      parent, children = subject.create_observation(encounter, obs_params)

      expect(parent.id).not_to be_nil
      expect(children[0].id).not_to be_nil
      expect(children[0].obs_group_id).to eq(parent.id)
    end

    SECONDS_PER_MINUTE = 60

    it 'saves obs_datetime as retrospective timestamp when provided' do
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      obs_params[:obs_datetime] = '2019-01-01'
      retro_time = Time.now.strftime('2019-01-01 %H:%M:%S').to_time

      observation = create_observation.call(obs_params)[0]
      time_diff = (retro_time - observation.obs_datetime).abs
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      expect(time_diff).to be <= (end_time - start_time)
    end
  end
end
