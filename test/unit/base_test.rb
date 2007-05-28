require File.dirname(__FILE__) + '/../test_helper'

class BaseTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
  end
  
  def teardown
    ActiveMerchant::Billing::Base.mode = :test
  end

  def test_get_gateway_by_name
    assert_equal BogusGateway, Base.gateway(:bogus)
  end

  def test_get_moneris_by_name
    assert_equal MonerisGateway, Base.gateway(:moneris)
  end

  def test_get_authorize_net_by_name
    assert_equal AuthorizeNetGateway, Base.gateway(:authorize_net)
  end

  def test_get_usay_epay_by_name
    assert_equal UsaEpayGateway, Base.gateway(:usa_epay)
  end
  
  def test_get_linkpoint_by_name
    assert_equal LinkpointGateway, Base.gateway(:linkpoint)
  end
  
  def test_get_authorize_net_deprecated
    assert_equal AuthorizedNetGateway, Base.gateway(:authorized_net)
  end

  def test_get_integration
    chronopay = Base.integration(:chronopay)
    assert_equal ActiveMerchant::Billing::Integrations::Chronopay, chronopay
    assert_instance_of ActiveMerchant::Billing::Integrations::Chronopay::Notification, chronopay.notification('name=cody')
  end

  def test_set_modes
    ActiveMerchant::Billing::Base.mode = :test
    assert_equal :test, ActiveMerchant::Billing::Base.mode
    assert_equal :test, ActiveMerchant::Billing::Base.gateway_mode
    assert_equal :test, ActiveMerchant::Billing::Base.integration_mode

    ActiveMerchant::Billing::Base.mode = :production
    assert_equal :production, ActiveMerchant::Billing::Base.mode
    assert_equal :production, ActiveMerchant::Billing::Base.gateway_mode
    assert_equal :production, ActiveMerchant::Billing::Base.integration_mode

    ActiveMerchant::Billing::Base.mode = :development
    ActiveMerchant::Billing::Base.gateway_mode = :test
    ActiveMerchant::Billing::Base.integration_mode = :staging
    assert_equal :development, ActiveMerchant::Billing::Base.mode
    assert_equal :test, ActiveMerchant::Billing::Base.gateway_mode
    assert_equal :staging, ActiveMerchant::Billing::Base.integration_mode
  end

end
