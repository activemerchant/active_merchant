require 'test_helper'

class ApplePayPaymentTokenTest < Test::Unit::TestCase
  def setup
    @token = ActiveMerchant::Billing::ApplePayPaymentToken.new(payment_data: {})
  end

  def test_type
    assert_equal 'apple_pay', @token.type
  end
end
