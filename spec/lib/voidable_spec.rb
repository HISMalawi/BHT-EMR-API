# frozen_string_literal: true

require 'rails_helper'
require 'voidable'

describe Voidable do
  before do
    @voidable = Class.new do
      include Voidable

      attr_accessor :voided
      attr_accessor :date_voided
      attr_accessor :void_reason
      attr_accessor :voided_by
    end
  end

  it 'sets void fields on `void`' do
    User.current_user = :foobar
    voidable_object = @voidable.new

    expect(voidable_object.save).to be_true
    expect(voidable_object.voided).to be_true
    expect(voidable_object.date_voided).to eq(Time.now)
    expect(voidable_object.voided_by).to eq(:foobar)
  end

  it 'trigger after_void callbacks' do
  end
end
