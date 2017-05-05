require 'test_helper'

class FocalPaymentNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @focal_payment = FocalPayment::Notification.new(https_raw_data, :secret => 'myKey')
  end

  def test_respond_to_acknowledge
    assert @focal_payment.respond_to?(:acknowledge)
  end

  def test_https_acknowledgement
    assert @focal_payment.acknowledge
  end

  def test_accessors
    assert_equal '6465nfn-5252-5252-5252-nhbnghjnghj', @focal_payment.account
    assert_equal 'test@focal.ru', @focal_payment.email
    assert_equal '85', @focal_payment.order
    assert_equal '100.00', @focal_payment.amount
    assert_equal 'CNY', @focal_payment.currency
    assert_equal '1', @focal_payment.test_trans
    assert_equal 'Apple', @focal_payment.product
    assert_equal '1', @focal_payment.attempt_mode
    assert_equal 'cup', @focal_payment.payment_type
    assert_equal '6465nfn-5252-5252-5252-nhbnghjnghj', @focal_payment.site
  end

  private

  def https_raw_data
    'TransId=c4792254-3a45-11e3-bbc8-0211eb00a4cc&\
TransRef=85&\
Email=elena%40aforex.ru&\
Amount=100.00&\
Currency=CNY&\
Status=4&\
Message=Blocked&\
Product=Aforex&\
Key=53b21b8a0569c4879f5a1f83ccf4d7c5&\
Test=true'
  end
end