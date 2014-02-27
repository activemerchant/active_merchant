require 'test_helper'

class RemoteMollieIdealIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_production_banklist
    MollieIdeal.stubs(:testmode).returns(false)
    banklist = MollieIdeal.banklist
    assert banklist.length > 0
  end

  def test_test_banklist
    MollieIdeal.stubs(:testmode).returns(true)
    banklist = MollieIdeal.banklist
    assert banklist.length == 1
    assert_equal ['TBM Bank', '9999'], banklist[0]
  end
end
