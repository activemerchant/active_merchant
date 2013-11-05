require 'test_helper'

class WirecardCheckoutPageReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @options = fixtures(:wirecard_checkout_page)
    @return = WirecardCheckoutPage::Return.new(http_raw_data, @options)
  end

  def test_return
    assert @return.success?
  end

  private
  def http_raw_data
    "amount=110.99&currency=EUR&paymentType=IDL&financialInstitution=INGBANK&language=de&orderNumber=9882408&paymentState=SUCCESS&utf8=%E2%9C%93&xActiveMerchantOrderId=13&consumerIpAddress=192.168.201.181&consumerUserAgent=Mozilla%2F5.0+%28X11%3B+Ubuntu%3B+Linux+x86_64%3B+rv%3A24.0%29+Gecko%2F20100101+Firefox%2F24.0&commit=Jetzt+bezahlen&idealConsumerName=Test+C%C3%B6ns%C3%BCmer+Utl%C3%B8psdato&idealConsumerBIC=RABONL2U&idealConsumerCity=RABONL2U&idealConsumerIBAN=NL17RABO0213698412&idealConsumerAccountNumber=NL17RABO0213698412&gatewayReferenceNumber=DGW_9882408_RN&gatewayContractNumber=DemoContractNumber123&avsResponseCode=X&avsResponseMessage=Demo+AVS+ResultMessage&responseFingerprintOrder=amount%2Ccurrency%2CpaymentType%2CfinancialInstitution%2Clanguage%2CorderNumber%2CpaymentState%2Cutf8%2CxActiveMerchantOrderId%2CconsumerIpAddress%2CconsumerUserAgent%2Ccommit%2CidealConsumerName%2CidealConsumerBIC%2CidealConsumerCity%2CidealConsumerIBAN%2CidealConsumerAccountNumber%2CgatewayReferenceNumber%2CgatewayContractNumber%2CavsResponseCode%2CavsResponseMessage%2Csecret%2CresponseFingerprintOrder&responseFingerprint=a15a4fceefcab5a41380f97079180d55"
  end

end
