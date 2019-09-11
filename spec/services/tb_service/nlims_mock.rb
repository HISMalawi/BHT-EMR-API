# frozen_string_literal: true

class NLims
  def self.instance
    new
  end

  def temp_auth
    OpenStruct.new(user: 'fake', token: 'foobar')
  end

  def connect(*)
    OpenStruct.new(user: 'fake', token: 'foobar')
  end

  def order_tb_test(*)
    {
      'tracking_number' => '1234567890'
    }
  end

  def specimen_types(*)
    ['Sputum']
  end

  def test_types
    ['TB Tests']
  end
end
