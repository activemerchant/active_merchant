require 'test_helper'

class YandexMoneyNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @yandex_money = YandexMoney::Notification.new(http_raw_data)
    @yandex_money.acknowledge('secret')
  end

  def test_accessors
    assert @yandex_money.complete?
    assert_equal "completed", @yandex_money.status
    assert_equal "2000012345", @yandex_money.transaction_id
    assert_equal "order-500", @yandex_money.item_id
    assert_equal 31.66, @yandex_money.gross
    assert_equal "643", @yandex_money.currency
    assert_equal "01-01-2001T18:00:00Z", @yandex_money.received_at
    assert_false @yandex_money.test?
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    @yandex_money.acknowledge('secret')
    assert_equal "0", @yandex_money.get_response
  end

  private
  def http_raw_data
    "action=paymentAviso&\
orderSumAmount=31.66&\
orderSumCurrencyPaycash=643&\
orderSumBankPaycash=1001&\
orderCreatedDatetime=01-01-2001T18:00:00Z&\
orderNumber=order-500&\
shopId=1234&\
invoiceId=2000012345&\
customerNumber=54321&\
md5=C5B03D2CEA0CD3F3BDB75826A4FA56B0"
  end
end
