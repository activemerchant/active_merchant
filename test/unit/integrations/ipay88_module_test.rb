require 'test_helper'

class Ipay88ModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_return_method
    assert_instance_of Ipay88::Return, Ipay88.return('name=cody')
  end

  def test_service_url
    assert_equal "https://www.mobile88.com/epayment/entry.asp", Ipay88.service_url
  end
end
