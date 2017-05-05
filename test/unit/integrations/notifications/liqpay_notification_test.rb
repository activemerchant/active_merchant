require 'test_helper'

class LiqpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @options = { :secret => '3HSiVfb06EVAbK39MWvlFdVJPyEKlnxhbJ' }
  end

  def test_successful_transaction_notification
    notification = Liqpay::Notification.new(successful_response, @options)

    assert notification.acknowledge
    assert notification.complete?
    assert notification.transaction_id.present?
    assert_match notification.gross, '1.00'
    assert_match notification.currency, 'RUR'
    assert_match notification.item_id, '17'
  end

  def test_failed_transaction_notification
    notification = Liqpay::Notification.new(failed_response, @options)

    assert notification.acknowledge
    assert !notification.complete?
    assert notification.transaction_id.present?
    assert_match notification.gross, '2410.00'
    assert_match notification.currency, 'RUR'
    assert_match notification.item_id, '19'
  end

  def test_exception_without_http_params
    assert_raise ArgumentError do
      Liqpay::Notification.new('')
    end
  end

  private

  def successful_response
    'signature=mOJdMHeDHlGlBY0NKZiI1wlU1BY%3D&operation_xml=PHJlc3BvbnNlPgo8c2VuZGVyX3Bob25lPis3OTA5NDM0MzMzNTwvc2VuZGVyX3Bob25lPgo8c3Rh%0AdHVzPnN1Y2Nlc3M8L3N0YXR1cz4KPHZlcnNpb24%2BMS4yPC92ZXJzaW9uPgo8b3JkZXJfaWQ%2BMTc8%0AL29yZGVyX2lkPgo8bWVyY2hhbnRfaWQ%2BaTU1MjA0Njg0OTg8L21lcmNoYW50X2lkPgo8cGF5X2Rl%0AdGFpbHM%2BPC9wYXlfZGV0YWlscz4KPGRlc2NyaXB0aW9uPsOQwp7DkMK%2Fw5DCu8OQwrDDkcKCw5DC%0AsCDDkcKHw5DCtcORwoDDkMK1w5DCtyDDkMK4w5DCvcORwoLDkMK1w5HCgMOQwr3DkMK1w5HCgi48%0AL2Rlc2NyaXB0aW9uPgo8Y3VycmVuY3k%2BUlVSPC9jdXJyZW5jeT4KPGFtb3VudD4xLjAwPC9hbW91%0AbnQ%2BCjxwYXlfd2F5PmNhcmQ8L3BheV93YXk%2BCjx0cmFuc2FjdGlvbl9pZD4yMTMxNjE0NTwvdHJh%0AbnNhY3Rpb25faWQ%2BCjxhY3Rpb24%2Bc2VydmVyX3VybDwvYWN0aW9uPgo8Y29kZT48L2NvZGU%2BCjwv%0AcmVzcG9uc2U%2B%0A'
  end

  def failed_response
    'operation_xml=PHJlc3BvbnNlPgogIDxhY3Rpb24%2BcmVzdWx0X3VybDwvYWN0aW9uPgogIDxhbW91bnQ%2BMjQxMC4w%0D%0AMDwvYW1vdW50PgogIDxjdXJyZW5jeT5SVVI8L2N1cnJlbmN5PgogIDxkZXNjcmlwdGlvbj7DkMKe%0D%0Aw5DCv8OQwrvDkMKww5HCgsOQwrAgw5HCh8OQwrXDkcKAw5DCtcOQwrcgw5DCuMOQwr3DkcKCw5DC%0D%0AtcORwoDDkMK9w5DCtcORwoIuPC9kZXNjcmlwdGlvbj4KICA8bWVyY2hhbnRfaWQ%2BaTU1MjA0Njg0%0D%0AOTg8L21lcmNoYW50X2lkPgogIDxvcmRlcl9pZD4xOTwvb3JkZXJfaWQ%2BCiAgPHBheV93YXk%2BY2Fy%0D%0AZDwvcGF5X3dheT4KICA8c2VuZGVyX3Bob25lPis3OTA5NDM0MzMzNTwvc2VuZGVyX3Bob25lPgog%0D%0AIDxzdGF0dXM%2BZmFpbHVyZTwvc3RhdHVzPgogIDx0cmFuc2FjdGlvbl9pZD4yMTMxOTU4MTwvdHJh%0D%0AbnNhY3Rpb25faWQ%2BCiAgPHZlcnNpb24%2BMS4yPC92ZXJzaW9uPgo8L3Jlc3BvbnNlPgo%3D%0D%0A&signature=b6a8U5Dg%2Fhl%2BNtYOIyjIwJH0Fi8%3D'
  end
end
