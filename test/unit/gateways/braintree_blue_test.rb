require 'test_helper'

class BraintreeBlueTest < Test::Unit::TestCase
  def setup
    # force it to load
    BraintreeBlueGateway.new(:merchant_id => "test", :public_key => "test", :private_key => "test")
  end

  def test_user_agent_includes_activemerchant_version
    assert Braintree::Configuration.user_agent.include?("(ActiveMerchant #{ActiveMerchant::VERSION})")
  end
end
