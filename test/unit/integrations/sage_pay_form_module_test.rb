require 'test_helper'

class SagePayFormModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_return_method
    assert_instance_of SagePayForm::Return, SagePayForm.return('name=cody', {})
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://live.sagepay.com/gateway/service/vspform-register.vsp', SagePayForm.service_url
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.sagepay.com/gateway/service/vspform-register.vsp', SagePayForm.service_url
  end

  def test_simulate_mode
    ActiveMerchant::Billing::Base.integration_mode = :simulate
    assert_equal 'https://test.sagepay.com/Simulator/VSPFormGateway.asp', SagePayForm.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :zoomin
    assert_raise(StandardError){ SagePayForm.service_url }
  end
  
end 
