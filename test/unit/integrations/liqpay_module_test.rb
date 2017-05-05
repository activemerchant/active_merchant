require 'test_helper'

class LiqpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Liqpay::Helper, Liqpay.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Liqpay::Notification, Liqpay.notification(http_post_data)
  end

  private

  def http_post_data
    'signature=mOJdMHeDHlGlBY0NKZiI1wlU1BY%3D&operation_xml=PHJlc3BvbnNlPgo8c2VuZGVyX3Bob25lPis3OTA5NDM0MzMzNTwvc2VuZGVyX3Bob25lPgo8c3Rh%0AdHVzPnN1Y2Nlc3M8L3N0YXR1cz4KPHZlcnNpb24%2BMS4yPC92ZXJzaW9uPgo8b3JkZXJfaWQ%2BMTc8%0AL29yZGVyX2lkPgo8bWVyY2hhbnRfaWQ%2BaTU1MjA0Njg0OTg8L21lcmNoYW50X2lkPgo8cGF5X2Rl%0AdGFpbHM%2BPC9wYXlfZGV0YWlscz4KPGRlc2NyaXB0aW9uPsOQwp7DkMK%2Fw5DCu8OQwrDDkcKCw5DC%0AsCDDkcKHw5DCtcORwoDDkMK1w5DCtyDDkMK4w5DCvcORwoLDkMK1w5HCgMOQwr3DkMK1w5HCgi48%0AL2Rlc2NyaXB0aW9uPgo8Y3VycmVuY3k%2BUlVSPC9jdXJyZW5jeT4KPGFtb3VudD4xLjAwPC9hbW91%0AbnQ%2BCjxwYXlfd2F5PmNhcmQ8L3BheV93YXk%2BCjx0cmFuc2FjdGlvbl9pZD4yMTMxNjE0NTwvdHJh%0AbnNhY3Rpb25faWQ%2BCjxhY3Rpb24%2Bc2VydmVyX3VybDwvYWN0aW9uPgo8Y29kZT48L2NvZGU%2BCjwv%0AcmVzcG9uc2U%2B%0A'
  end
end
