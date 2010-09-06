require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase
  def test_initialize_does_not_raise_an_error
    assert_nothing_raised do
      BraintreeBlueGateway.new(:merchant_id => "test", :public_key => "test", :private_key => "test")
    end
  end
end
