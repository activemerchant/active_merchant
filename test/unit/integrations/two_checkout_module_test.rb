require 'test_helper'

class TwoCheckoutModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_default_service_url
    assert_equal 'https://www.2checkout.com/checkout/spurchase', TwoCheckout.service_url
  end
  
  def test_legacy_service_url_writer
    TwoCheckout.service_url = 'https://www.2checkout.com/checkout/purchase'
    assert_equal :multi_page, TwoCheckout.payment_routine
  end
  
  def test_single_page_payment_routine_service_url
    TwoCheckout.payment_routine = :single_page
    assert_equal 'https://www.2checkout.com/checkout/spurchase', TwoCheckout.service_url
  end
  
  def test_multi_page_payment_routine_service_url
    TwoCheckout.payment_routine = :multi_page
    assert_equal 'https://www.2checkout.com/checkout/purchase', TwoCheckout.service_url
  end
  
  def test_notification_method
    assert_instance_of TwoCheckout::Notification, TwoCheckout.notification('name=cody', {})
  end
  
  def test_return_method
    assert_instance_of TwoCheckout::Return, TwoCheckout.return('name=cody', {})
  end
end 
