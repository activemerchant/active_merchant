require 'test_helper'

class DotpayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_return_is_always_succesful
    r = Dotpay::Return.new("")
    assert r.success?
  end
end