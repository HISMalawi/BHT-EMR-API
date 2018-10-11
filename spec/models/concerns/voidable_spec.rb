# frozen_string_literal: true

require 'rails_helper'

describe Voidable do
  # DB schema is tinyint not bool for voided
  VOIDED = 1

  before do
    @voidable = (Class.new do
      include Voidable

      after_void :on_after_void

      attr_accessor :voided
      attr_accessor :date_voided
      attr_accessor :void_reason
      attr_accessor :voided_by
      attr_reader :after_void

      def initialize
        @voided = 0
        @after_void = nil
      end

      def save
        true
      end

      def on_after_void(reason)
        @after_void = reason
      end
    end).new

    @user = (Class.new do
      attr_accessor :user_id

      def initialize
        @user_id = :user
      end
    end).new
  end

  it 'sets void fields on `void`' do
    User.current = @user

    expect(@voidable.void(:pumbwa)).to be true
    expect(@voidable.voided).to be VOIDED
    # A 5 minutes delay in execution seems reasonable
    expect(@voidable.date_voided).to be > (Time.now - 5.minutes)
    expect(@voidable.voided_by).to eq(@user.user_id)
    expect(@voidable.void_reason).to eq(:pumbwa)
  end

  it 'is able to re-map void interface' do
    retirable = (Class.new do
      include Voidable

      attr_accessor :retired, :date_retired, :retire_reason, :retired_by

      remap_voidable_interface(
        voided: :retired,
        date_voided: :date_retired,
        void_reason: :retire_reason,
        voided_by: :retired_by
      )

      def initialize
        @voided = 0
      end

      def id
        :pumbwa_id
      end

      def save
        true
      end
    end).new

    retirable.void(:pumbwa)
    expect(retirable.retired).to eq(1)
    expect(retirable.date_retired).to be > (Time.now - 5.minutes)
    expect(retirable.retired_by).to eq(@user.user_id)
    expect(retirable.retire_reason).to eq(:pumbwa)
  end

  it 'triggers after_void callbacks' do
    @voidable.void :pumbwa
    expect(@voidable.after_void).to be :pumbwa
  end
end
