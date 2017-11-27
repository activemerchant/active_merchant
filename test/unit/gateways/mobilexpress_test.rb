require 'test_helper'

class MobilexpressTest < Test::Unit::TestCase
  def setup
    @gateway = MobilexpressGateway.new(merchant_key: 'd011eacb-9109-46a0-ac3f-2080e77ce6ef', api_password: 'foo')
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

    assert_equal '0;103400', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(@credit_card)

    assert_success response
    assert_equal '070a1e62-e637-4909-a7db-ac4f46ccb9de', response.authorization
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    response = @gateway.unstore('foobar-token')

    assert_success response
    assert_equal 'Success', response.params['delete_credit_card_result']
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card)

    assert_failure response
    assert_equal 'InvalidCustomerID', response.message
  end

  def test_failed_unstore
    @gateway.expects(:ssl_post).returns(failed_unstore_response)
    response = @gateway.unstore('something')

    assert_failure response
    assert_equal 'CustomerNotFound', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-XML
opening connection to test.mobilexpress.com.tr:443...
opened
starting SSL for test.mobilexpress.com.tr:443...
SSL established
<- "POST /Checkout/v6/FastCheckoutService.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: http://tempuri.org/ProcessPaymentWithCard\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.mobilexpress.com.tr\r\nContent-Length: 511\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessPaymentWithCard xmlns=\"http://tempuri.org/\"><ProcessType>sales</ProcessType><MerchantKey>d011eacb-9109-46a0-ac3f-2080e77ce6ef</MerchantKey><APIpassword>foo</APIpassword><TotalAmount>1.00</TotalAmount><Request3D>false</Request3D><CardNum>4603454603454606</CardNum><LastMonth>12</LastMonth><LastYear>2018</LastYear><CVV>000</CVV></ProcessPaymentWithCard></s:Body></s:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Fri, 24 Nov 2017 00:54:19 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 623\r\n"
-> "\r\n"
reading 623 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentWithCardResponse xmlns=\"http://tempuri.org/\"><ProcessPaymentWithCardResult><ResultCode>Success</ResultCode><ErrorMessage /><MobilexpressTransId>0</MobilexpressTransId><BankReturnCode>00</BankReturnCode><BankAuthCode>953127</BankAuthCode><BankTransId>17328D4KJ10749</BankTransId><POSID>28347</POSID></ProcessPaymentWithCardResult></ProcessPaymentWithCardResponse></soap:Body></soap:Envelope>"
read 623 bytes
Conn close
    XML
  end

  def post_scrubbed
    <<-XML
opening connection to test.mobilexpress.com.tr:443...
opened
starting SSL for test.mobilexpress.com.tr:443...
SSL established
<- "POST /Checkout/v6/FastCheckoutService.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: http://tempuri.org/ProcessPaymentWithCard\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.mobilexpress.com.tr\r\nContent-Length: 511\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ProcessPaymentWithCard xmlns=\"http://tempuri.org/\"><ProcessType>sales</ProcessType><MerchantKey>[FILTERED]</MerchantKey><APIpassword>[FILTERED]</APIpassword><TotalAmount>1.00</TotalAmount><Request3D>false</Request3D><CardNum>[FILTERED]</CardNum><LastMonth>12</LastMonth><LastYear>2018</LastYear><CVV>[FILTERED]</CVV></ProcessPaymentWithCard></s:Body></s:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Fri, 24 Nov 2017 00:54:19 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 623\r\n"
-> "\r\n"
reading 623 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentWithCardResponse xmlns=\"http://tempuri.org/\"><ProcessPaymentWithCardResult><ResultCode>Success</ResultCode><ErrorMessage /><MobilexpressTransId>0</MobilexpressTransId><BankReturnCode>00</BankReturnCode><BankAuthCode>953127</BankAuthCode><BankTransId>17328D4KJ10749</BankTransId><POSID>28347</POSID></ProcessPaymentWithCardResult></ProcessPaymentWithCardResponse></soap:Body></soap:Envelope>"
read 623 bytes
Conn close
    XML
  end

  def successful_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentWithCardResponse xmlns=\"http://tempuri.org/\"><ProcessPaymentWithCardResult><ResultCode>Success</ResultCode><ErrorMessage /><MobilexpressTransId>0</MobilexpressTransId><BankReturnCode>00</BankReturnCode><BankAuthCode>103400</BankAuthCode><BankTransId>17328ECgB10782</BankTransId><POSID>28347</POSID></ProcessPaymentWithCardResult></ProcessPaymentWithCardResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessPaymentWithCardResponse xmlns=\"http://tempuri.org/\"><ProcessPaymentWithCardResult><ResultCode>CardRefused</ResultCode><ErrorMessage>\xC3\x96demeniz Banka Taraf\xC4\xB1ndan Reddedildi. L\xC3\xBCten kart bilgilerinizi kontrol edip tekrar deneyiniz.</ErrorMessage><MobilexpressTransId>0</MobilexpressTransId><BankReturnCode>12</BankReturnCode><BankAuthCode /><BankTransId>17328ECaB10778</BankTransId><BankMessage>Gecersiz Transaction.</BankMessage><POSID>28347</POSID></ProcessPaymentWithCardResult></ProcessPaymentWithCardResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_store_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><SaveCreditCardResponse xmlns=\"http://tempuri.org/\"><SaveCreditCardResult><ResultCode>Success</ResultCode><CardToken>070a1e62-e637-4909-a7db-ac4f46ccb9de</CardToken></SaveCreditCardResult></SaveCreditCardResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_unstore_response
  %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><DeleteCreditCardResponse xmlns=\"http://tempuri.org/\"><DeleteCreditCardResult>Success</DeleteCreditCardResult></DeleteCreditCardResponse></soap:Body></soap:Envelope>
  )
  end

  def failed_store_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><SaveCreditCardResponse xmlns=\"http://tempuri.org/\"><SaveCreditCardResult><ResultCode>InvalidCustomerID</ResultCode></SaveCreditCardResult></SaveCreditCardResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_unstore_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><DeleteCreditCardResponse xmlns=\"http://tempuri.org/\"><DeleteCreditCardResult>CustomerNotFound</DeleteCreditCardResult></DeleteCreditCardResponse></soap:Body></soap:Envelope>
    )
  end
end
