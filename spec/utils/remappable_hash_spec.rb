# frozen_string_literal: true

require 'rails_helper'
require 'utils/remappable_hash'

describe Hash do
  describe 'remap_field' do
    it 'renames existing field to new name' do
      hash = { a: :c }
      hash.remap_field! :a, :b

      expect(hash).to include(:b)
      expect(hash).not_to include(:a)
      expect(hash[:b]).to be(:c)
    end
  end

  it 'throws exception if field does not exist' do
    hash = { a: :c }

    expect { hash.remap_field! :b, :a }.to raise_exception(KeyError)
  end
end
