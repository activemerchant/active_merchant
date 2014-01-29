require 'test_helper'

class RemoteDokuIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @doku = Doku::Notification.new(http_raw_data, :credential2 => 'GX7L65D8U1AY')
  end

  def test_raw
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal "https://apps.myshortcart.com/payment/request-payment/", Doku.service_url

    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal "https://apps.myshortcart.com/payment/request-payment/", Doku.service_url

    assert_nothing_raised do
      assert @doku.acknowledge
    end
  end

  private
  def http_raw_data
   "AMOUNT=75000.0&BASKET=Gold%2C70000.00%2C1%2C70000.00%3BAdministration+fee%2C5000.00%2C1%2C5000.0&BIRTHDATE=1988-06-1&CADDRESS=Plaza+Asia+Office+Park+Unit+3+Kav+59&CCITY=JAKARTA&CCOUNTRY=20&CEMAIL=buayo%40gmail.com&CHPHONE=021098090&CMPHONE=08129809809&CNAME=Buayo+Putr&CSTATE=DKI&CWPHONE=021000001&CZIPCODE=12190&SADDRESS=Pengadegan+Barat+V+no+17F&SCITY=JAKARTA&SCOUNTRY=784&SSTATE=DKI&STOREID=00107259&SZIPCODE=12217&TRANSIDMERCHANT=ORD12345&URL=http%3A%2F%2Fwww.yourwebsite.com%2F&WORDS=01447c3901946b4d55d64175e92ec5c276a58566"
  end
end
