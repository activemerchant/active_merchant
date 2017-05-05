require 'test_helper'

class PayFastModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of PayFast::Helper, PayFast.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of PayFast::Notification, PayFast.notification('name=cody')
  end

  def test_test_process_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://sandbox.payfast.co.za/eng/process', PayFast.service_url
  end

  def test_test_validate_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://sandbox.payfast.co.za/eng/query/validate', PayFast.validate_service_url
  end

  def test_production_process_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.payfast.co.za/eng/process', PayFast.service_url
  end

  def test_production_validate_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.payfast.co.za/eng/query/validate', PayFast.validate_service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :winterfell
    assert_raise(StandardError) { PayFast.service_url }
    assert_raise(StandardError) { PayFast.validate_service_url }
  end
end
