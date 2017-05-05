require 'test_helper'

class PayonlineNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @payonline = Payonline::Notification.new(https_raw_data, :secret => 'myKey')
  end

  def test_respond_to_acknowledge
    assert @payonline.respond_to?(:acknowledge)
  end

  def test_https_acknowledgement
    assert @payonline.acknowledge
  end

  # def test_accessors
  #   assert_equal '2013-09-11 10:13:06', @payonline.date_time
  #   assert_equal '15694807', @payonline.transaction_id
  #   assert_equal '58', @payonline.order_id
  #   assert_equal '1.00', @payonline.amount
  #   assert_equal 'USD', @payonline.currency
  #   assert_equal 'd76245be538ca257582210e4961f3399', @payonline.security_key
  #   assert_equal '1.00', @payonline.payment_amount
  #   assert_equal 'USD', @payonline.payment_currency
  #   assert_equal 'ANDREY PETROV', @payonline.card_holder
  #   assert_equal '************5807', @payonline.card_number
  #   assert_equal 'RU', @payonline.country
  # end

  private

  def https_raw_data
    "Amount=1.00&CardHolder=ANDREY+PETROV&CardNumber=%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A%2A5807&City=Moskva&Country=RU&Currency=USD&DateTime=2013-09-27+10%3A45%3A40&ECI=5&OrderId=62&PaymentAmount=1.00&PaymentCurrency=USD&Provider=Card&SecurityKey=ae9da6f23c2a2a73c59c934bd98bbc40&TransactionID=16059153&authenticity_token=LNKJAULAqitmO2TiN6tWsRoPKvL3qcm47fLPIbPypNQ%3D&commit=Payment+money&utf8=%E2%9C%93"
#     "DateTime=2013-09-11+10:13:06&\
# TransactionID=15694807&\
# OrderId=58&\
# Amount=1.00&\
# Currency=USD&\
# SecurityKey=d76245be538ca257582210e4961f3399&\
# PaymentAmount=1.00&\
# PaymentCurrency=USD&\
# CardHolder=ANDREY PETROV&\
# CardNumber=************5807&\
# Country=RU"
  end
end