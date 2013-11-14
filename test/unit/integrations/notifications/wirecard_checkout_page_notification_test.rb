require 'test_helper'

class WirecardCheckoutPageNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @options = fixtures(:wirecard_checkout_page)
    @wirecard_checkout_page = WirecardCheckoutPage::Notification.new(http_raw_data, @options)
  end

  def test_accessors
    @wirecard_checkout_page.acknowledge
    assert_equal nil, @wirecard_checkout_page.message
    assert @wirecard_checkout_page.complete?
    assert_equal "13", @wirecard_checkout_page.item_id
    assert_equal "110.99", @wirecard_checkout_page.gross
    assert_equal "EUR", @wirecard_checkout_page.currency
    assert_equal "IDL", @wirecard_checkout_page.paymentType
  end

  def test_send_acknowledgement
    assert_equal '<QPAY-CONFIRMATION-RESPONSE result="OK"/>', @wirecard_checkout_page.response
  end

  def test_respond_to_acknowledge
    assert @wirecard_checkout_page.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "amount=110.99&currency=EUR&paymentType=IDL&financialInstitution=INGBANK&language=de&orderNumber=9882408&paymentState=SUCCESS&utf8=%E2%9C%93&xActiveMerchantOrderId=13&consumerIpAddress=192.168.201.181&consumerUserAgent=Mozilla%2F5.0+%28X11%3B+Ubuntu%3B+Linux+x86_64%3B+rv%3A24.0%29+Gecko%2F20100101+Firefox%2F24.0&commit=Jetzt+bezahlen&idealConsumerName=Test+C%C3%B6ns%C3%BCmer+Utl%C3%B8psdato&idealConsumerBIC=RABONL2U&idealConsumerCity=RABONL2U&idealConsumerIBAN=NL17RABO0213698412&idealConsumerAccountNumber=NL17RABO0213698412&gatewayReferenceNumber=DGW_9882408_RN&gatewayContractNumber=DemoContractNumber123&avsResponseCode=X&avsResponseMessage=Demo+AVS+ResultMessage&responseFingerprintOrder=amount%2Ccurrency%2CpaymentType%2CfinancialInstitution%2Clanguage%2CorderNumber%2CpaymentState%2Cutf8%2CxActiveMerchantOrderId%2CconsumerIpAddress%2CconsumerUserAgent%2Ccommit%2CidealConsumerName%2CidealConsumerBIC%2CidealConsumerCity%2CidealConsumerIBAN%2CidealConsumerAccountNumber%2CgatewayReferenceNumber%2CgatewayContractNumber%2CavsResponseCode%2CavsResponseMessage%2Csecret%2CresponseFingerprintOrder&responseFingerprint=a15a4fceefcab5a41380f97079180d55"
  end
end
