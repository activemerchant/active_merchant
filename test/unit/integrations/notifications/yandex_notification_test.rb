require 'test_helper'

class YandexNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @yandex = Yandex::Notification.new(http_raw_data, :secret => 'secret')
  end

  def test_accessors
    assert @yandex.complete?
    assert !@yandex.check?
    assert_equal "success", @yandex.status
    assert_equal "0909", @yandex.transaction_id
    assert_equal "09834", @yandex.item_id
    assert_equal "400", @yandex.gross
    assert_equal "RUR", @yandex.currency
    assert !@yandex.test?
  end

  def test_compositions
    assert_equal 400, @yandex.amount
  end

  def test_acknowledgement
    puts ActiveMerchant::Billing::Integrations::Yandex.signature_parameter_name
    puts @yandex.security_key
    assert @yandex.acknowledge
  end

  def test_wrong_signature
    yandex = Yandex::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret')
    assert !yandex.acknowledge
  end

  def test_respond_to_acknowledge
    assert @yandex.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    "shopId=9384&orderNumber=09834&request_type=payment_success&orderIsPaid=1&invoiceId=0909&orderSumAmount=400&md5=e49ac35a5a93284597bc5adb5f348cf1"
  end

  def http_raw_data_with_wrong_signature
    "InvId=123&OutSum=500&SignatureValue=wrong&shpMySuperParam=456&shpa=123&md5=1"
  end
end
