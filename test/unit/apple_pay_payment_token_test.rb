require 'test_helper'

class ApplePayPaymentTokenTest < Test::Unit::TestCase
  def setup
    @token = apple_pay_payment_token
  end

  def test_type
    assert_equal 'apple_pay', @token.type
  end

  def test_encrypted_payment_data
    assert_equal apple_pay_payment_token.payment_data[:data], @token.encrypted_payment_data
  end
end
