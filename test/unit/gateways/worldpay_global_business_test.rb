require 'test_helper'

class WorldpayGlobalBusinessTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayGlobalBusinessGateway.new(username: 'login', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '788f4b4f666771b60aaf074a41ef60d9', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    error_expected = WorldpayGlobalBusinessGateway::STANDARD_ERROR_CODE_MAPPING['5']
    assert_equal error_expected, response.error_code
  end


  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to secure-test.worldpay.com:443...
      opened
starting SSL for secure-test.worldpay.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /jsp/merchant/xml/paymentService.jsp HTTP/1.1
Content-Type: text/xml
Authorization: Basic RUxETTZRRDVCWVkyWTVER1ZEUUQ6bjE4VCFwM0JUQHR1TiRv
Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
Accept: */*
User-Agent: Ruby
Connection: close
Host: secure-test.worldpay.com
Content-Length: 1074"
<- "<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
<paymentService version="1.4" merchantCode="UNHCRLAMECOM">
  <submit>
    <order orderCode="fdec4e066c1b95ccc934a3dfeccb4d8c">
      <description>Store Purchase</description>
      <amount value="100" currencyCode="GBP" exponent="2"/>
      <paymentDetails>
        <CARD-SSL>
          <cardNumber>4444333322221111</cardNumber>
          <expiryDate>
            <date month="9" year="2021"/>
          </expiryDate>
          <cardHolderName>Longbob Longsen</cardHolderName>
          <cardAddress>
            <address>
              <address1>456 My Street</address1>
              <address2>Apt 1</address2>
              <postalCode>K1C2N6</postalCode>
              <city>Ottawa</city>
              <state>ON</state>
              <countryCode>CA</countryCode>
            </address>
          </cardAddress>
        </CARD-SSL>
      </paymentDetails>
    </order>
  </submit>
  </paymentService>"
-> "HTTP/1.1 200 OK"
-> "Date: Mon, 09 Nov 2020 22:14:29 GMT"
-> "Server: Apache"
-> "Content-Length: 1035"
-> "P3P: CP="NON""
-> "Set-Cookie: machine=0ab20016;path=/"
-> "Content-Type: text/plain"
-> "X-XSS-Protection: 1; mode=block"
-> "X-Content-Type-Options: nosniff"
-> "Strict-Transport-Security: max-age=3156000; includeSubDomains; preload"
-> "Connection: close"
-> ""
reading 1035 bytes...
-> "<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                "http://dtd.worldpay.com/paymentService_v1.dtd">
                                <paymentService version="1.4" merchantCode="UNHCRLAMECOM"><reply><orderStatus orderCode="fdec4e066c1b95ccc934a3dfeccb4d8c"><payment><paymentMethod>VISA_CREDIT-SSL</paymentMethod><amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/><lastEvent>AUTHORISED</lastEvent><CVCResultCode description="NOT SUPPLIED BY SHOPPER"/><AAVAddressResultCode description="UNKNOWN"/><AAVPostcodeResultCode description="UNKNOWN"/><AAVCardholderNameResultCode description="UNKNOWN"/><AAVTelephoneResultCode description="UNKNOWN"/><AAVEmailResultCode description="UNKNOWN"/><balance accountType="IN_PROCESS_AUTHORISED"><amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/></balance><cardNumber>4444********1111</cardNumber><riskScore value="20"/></payment></orderStatus></reply></paymentService>
"
read 1035 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to secure-test.worldpay.com:443...
      opened
starting SSL for secure-test.worldpay.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /jsp/merchant/xml/paymentService.jsp HTTP/1.1
Content-Type: text/xml
Authorization: Basic [FILTERED]
Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3
Accept: */*
User-Agent: Ruby
Connection: close
Host: secure-test.worldpay.com
Content-Length: 1074"
<- "<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN" "http://dtd.worldpay.com/paymentService_v1.dtd">
<paymentService version="1.4" merchantCode="UNHCRLAMECOM">
  <submit>
    <order orderCode="fdec4e066c1b95ccc934a3dfeccb4d8c">
      <description>Store Purchase</description>
      <amount value="100" currencyCode="GBP" exponent="2"/>
      <paymentDetails>
        <CARD-SSL>
          <cardNumber>[FILTERED]</cardNumber>
          <expiryDate>
            <date month="9" year="2021"/>
          </expiryDate>
          <cardHolderName>Longbob Longsen</cardHolderName>
          <cardAddress>
            <address>
              <address1>456 My Street</address1>
              <address2>Apt 1</address2>
              <postalCode>K1C2N6</postalCode>
              <city>Ottawa</city>
              <state>ON</state>
              <countryCode>CA</countryCode>
            </address>
          </cardAddress>
        </CARD-SSL>
      </paymentDetails>
    </order>
  </submit>
  </paymentService>"
-> "HTTP/1.1 200 OK"
-> "Date: Mon, 09 Nov 2020 22:14:29 GMT"
-> "Server: Apache"
-> "Content-Length: 1035"
-> "P3P: CP="NON""
-> "Set-Cookie: machine=0ab20016;path=/"
-> "Content-Type: text/plain"
-> "X-XSS-Protection: 1; mode=block"
-> "X-Content-Type-Options: nosniff"
-> "Strict-Transport-Security: max-age=3156000; includeSubDomains; preload"
-> "Connection: close"
-> ""
reading 1035 bytes...
-> "<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                "http://dtd.worldpay.com/paymentService_v1.dtd">
                                <paymentService version="1.4" merchantCode="UNHCRLAMECOM"><reply><orderStatus orderCode="fdec4e066c1b95ccc934a3dfeccb4d8c"><payment><paymentMethod>VISA_CREDIT-SSL</paymentMethod><amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/><lastEvent>AUTHORISED</lastEvent><CVCResultCode description="NOT SUPPLIED BY SHOPPER"/><AAVAddressResultCode description="UNKNOWN"/><AAVPostcodeResultCode description="UNKNOWN"/><AAVCardholderNameResultCode description="UNKNOWN"/><AAVTelephoneResultCode description="UNKNOWN"/><AAVEmailResultCode description="UNKNOWN"/><balance accountType="IN_PROCESS_AUTHORISED"><amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/></balance><cardNumber>4444********1111</cardNumber><riskScore value="20"/></payment></orderStatus></reply></paymentService>
"
read 1035 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                      "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="UNHCRLAMECOM">
        <reply>
          <orderStatus orderCode="788f4b4f666771b60aaf074a41ef60d9">
            <payment>
              <paymentMethod>VISA_CREDIT-SSL</paymentMethod>
              <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>AUTHORISED</lastEvent>
              <CVCResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <AAVAddressResultCode description="UNKNOWN"/><AAVPostcodeResultCode description="UNKNOWN"/>
              <AAVCardholderNameResultCode description="UNKNOWN"/><AAVTelephoneResultCode description="UNKNOWN"/>
              <AAVEmailResultCode description="UNKNOWN"/>
              <balance accountType="IN_PROCESS_AUTHORISED">
                <amount value="100" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              </balance>
              <cardNumber>4444********1111</cardNumber>
              <riskScore value="20"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    XML
  end

  def failed_purchase_response
    <<-XML
      <!DOCTYPE paymentService PUBLIC "-//WorldPay//DTD WorldPay PaymentService v1//EN"
                                "http://dtd.worldpay.com/paymentService_v1.dtd">
      <paymentService version="1.4" merchantCode="UNHCRLAMECOM">
        <reply>
          <orderStatus orderCode="4a514d32fed6762e0bce38f74bfe3abc">
            <payment>
              <paymentMethod>VISA_CREDIT-SSL</paymentMethod>
              <amount value="310" currencyCode="GBP" exponent="2" debitCreditIndicator="credit"/>
              <lastEvent>REFUSED</lastEvent>
              <ISO8583ReturnCode code="5" description="REFUSED"/>
              <CVCResultCode description="NOT SUPPLIED BY SHOPPER"/>
              <AAVAddressResultCode description="UNKNOWN"/>
              <AAVPostcodeResultCode description="UNKNOWN"/>
              <AAVCardholderNameResultCode description="UNKNOWN"/>
              <AAVTelephoneResultCode description="UNKNOWN"/>
              <AAVEmailResultCode description="UNKNOWN"/>
              <riskScore value="20"/>
            </payment>
          </orderStatus>
        </reply>
      </paymentService>
    XML
  end
end
