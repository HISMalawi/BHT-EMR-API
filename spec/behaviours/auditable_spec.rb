# frozen_string_literal: true

require 'rails_helper'
require 'auditable'

describe Auditable do
  before do
    @auditable = (Class.new do
      cattr_reader :before_save_callback
      attr_accessor :changed_by, :date_changed

      def self.before_save(callback)
        @@before_save_callback = callback
      end

      include Auditable
    end).new
  end

  it 'sets before_save callback' do
    expect(@auditable.before_save_callback).not_to be_nil
  end

  describe 'before_save callback' do
    it 'attaches logged in user to model updates' do
      User.current = (Class.new do
        attr_reader :id
      end).new

      User.current.id = :user

      # Triggers before_save callback
      @auditable.method(@auditable.before_save_callback).call

      expect(@auditable.changed_by).to be(:user)
      expect(@auditable.date_changed).to be > (Time.now - 5.minutes)
    end
  end
end
