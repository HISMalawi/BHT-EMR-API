# frozen_string_literal: true

require 'rails_helper'
require 'voidable'

describe Voidable do
  before do
    @voidable = (Class.new do
      include Voidable

      attr_accessor :voided
      attr_accessor :date_voided
      attr_accessor :void_reason
      attr_accessor :voided_by

      def initialize
        @voided = 0
      end
    end).new

    @user = (Class.new do
      attr_accessor :id

      def initialize
        @id = :user
      end
    end).new
  end

  it 'sets void fields on `void`' do
    User.current_user = @user
    voidable_object = @voidable

    expect(voidable_object.void('pumbwa')).to be true
    expect(voidable_object.voided).to be true
    expect(voidable_object.date_voided).to eq(Time.now)
    expect(voidable_object.voided_by).to eq(@user)
    expect(voidable_object.void_reason).to eq('pumbwa')
  end

  it 'triggers after_void callbacks' do
  end
end
