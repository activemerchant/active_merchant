require File.dirname(__FILE__) + '/../../../test_helper'

class TwoCheckoutReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_return
    r = TwoCheckout::Return.new('')
    assert r.success?
  end
end