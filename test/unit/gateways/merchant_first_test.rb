require 'test_helper'

class MerchantFirstTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MerchantFirstGateway.new(
      username: 'user',
      password: 'password',
      service_username: 'svcuser',
      service_password: 'svcpasswd',
      merchant_id: 000000,
    )
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('5454545454545454', year: (Time.now - 1.year).year)
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

    assert_equal '505995028', response.authorization
    assert_equal '0: Approved | ', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_session_id_response, successful_addcof_response)
    assert_success response
    assert_equal '1023050306435454', response.authorization
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    @gateway.expects(:ssl_post).returns(successful_void_response)
    void = @gateway.void(response.params['mcs_transaction_id'], @options)
    assert_success void
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    refund = @gateway.refund(@amount, response.params['mcs_transaction_id'], @options)
    assert_success refund
  end

  private

  def successful_session_id_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><AddSessionID_SoapResponse xmlns=\"https://MyCardStorage.com/\"><AddSessionID_SoapResult><SessionID>mEK8!Vpw</SessionID></AddSessionID_SoapResult></AddSessionID_SoapResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_addcof_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><AddCOF_SoapResponse xmlns=\"https://MyCardStorage.com/\"><AddCOF_SoapResult><TokenData><Token>1023050306435454</Token><TokenType>0</TokenType><CardNumber>5454545454545454</CardNumber><CardType>3</CardType><ExpirationMonth>8</ExpirationMonth><ExpirationYear>2018</ExpirationYear><FirstName>Bob</FirstName><LastName>Bobsen</LastName></TokenData><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved</ResultDetail></Result></AddCOF_SoapResult></AddCOF_SoapResponse></soap:Body></soap:Envelope>
    )
  end


  def pre_scrubbed
    <<-XML
opening connection to beta.mycardstorage.com:443...
opened
starting SSL for beta.mycardstorage.com:443...
SSL established
<- "POST /api/api.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://MyCardStorage.com/CreditSale_Soap\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: beta.mycardstorage.com\r\nContent-Length: 1421\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Header>\n    <AuthHeader xmlns=\"https://MyCardStorage.com/\">\n      <UserName>Foo</UserName>\n      <Password>Bar</Password>\n    </AuthHeader>\n  </soap12:Header>\n  <soap12:Body>\n    <CreditSale_Soap xmlns=\"https://MyCardStorage.com/\">\n      <creditCardSale>\n        <ServiceSecurity>\n          <ServiceUserName>FooSvc</ServiceUserName>\n          <ServicePassword>BarSvc</ServicePassword>\n          <MCSAccountID>000000</MCSAccountID>\n        </ServiceSecurity>\n        <TokenData>\n          <TokenType>0</TokenType>\n          <CardNumber>5454545454545454</CardNumber>\n          <CardType>4</CardType>\n          <ExpirationMonth>09</ExpirationMonth>\n          <ExpirationYear>2018</ExpirationYear>\n          <FirstName>Longbob</FirstName>\n          <LastName>Longsen</LastName>\n          <StreetAddress>456 My Street</StreetAddress>\n          <ZipCode>K1C2N6</ZipCode>\n          <CVV>123</CVV>\n        </TokenData>\n        <TransactionData>\n          <Amount>1.00</Amount>\n          <CurrencyCode>840</CurrencyCode>\n          <GatewayID>1</GatewayID>\n        </TransactionData>\n      </creditCardSale>\n    </CreditSale_Soap>\n  </soap12:Body>\n</soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Headers: accept, content-type, soapaction\r\n"
-> "Access-Control-Request-Method: POST\r\n"
-> "Date: Mon, 20 Feb 2017 00:37:16 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 671\r\n"
-> "\r\n"
reading 671 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditSale_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditSale_SoapResult><MCSTransactionID>886403</MCSTransactionID><ProcessorTransactionID>505995028</ProcessorTransactionID><Amount>1.00</Amount><TicketNumber /><ReferenceNumber /><ProcessorApprovalCode>TEST</ProcessorApprovalCode><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved | </ResultDetail></Result></CreditSale_SoapResult></CreditSale_SoapResponse></soap:Body></soap:Envelope>"
read 671 bytes
Conn close
    XML
  end

  def post_scrubbed
    <<-XML
opening connection to beta.mycardstorage.com:443...
opened
starting SSL for beta.mycardstorage.com:443...
SSL established
<- "POST /api/api.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://MyCardStorage.com/CreditSale_Soap\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: beta.mycardstorage.com\r\nContent-Length: 1421\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Header>\n    <AuthHeader xmlns=\"https://MyCardStorage.com/\">\n      <UserName>[FILTERED]</UserName>\n      <Password>[FILTERED]</Password>\n    </AuthHeader>\n  </soap12:Header>\n  <soap12:Body>\n    <CreditSale_Soap xmlns=\"https://MyCardStorage.com/\">\n      <creditCardSale>\n        <ServiceSecurity>\n          <ServiceUserName>[FILTERED]</ServiceUserName>\n          <ServicePassword>[FILTERED]</ServicePassword>\n          <MCSAccountID>000000</MCSAccountID>\n        </ServiceSecurity>\n        <TokenData>\n          <TokenType>0</TokenType>\n          <CardNumber>[FILTERED]</CardNumber>\n          <CardType>4</CardType>\n          <ExpirationMonth>09</ExpirationMonth>\n          <ExpirationYear>2018</ExpirationYear>\n          <FirstName>Longbob</FirstName>\n          <LastName>Longsen</LastName>\n          <StreetAddress>456 My Street</StreetAddress>\n          <ZipCode>K1C2N6</ZipCode>\n          <CVV>[FILTERED]</CVV>\n        </TokenData>\n        <TransactionData>\n          <Amount>1.00</Amount>\n          <CurrencyCode>840</CurrencyCode>\n          <GatewayID>1</GatewayID>\n        </TransactionData>\n      </creditCardSale>\n    </CreditSale_Soap>\n  </soap12:Body>\n</soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Headers: accept, content-type, soapaction\r\n"
-> "Access-Control-Request-Method: POST\r\n"
-> "Date: Mon, 20 Feb 2017 00:37:16 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 671\r\n"
-> "\r\n"
reading 671 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditSale_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditSale_SoapResult><MCSTransactionID>886403</MCSTransactionID><ProcessorTransactionID>505995028</ProcessorTransactionID><Amount>1.00</Amount><TicketNumber /><ReferenceNumber /><ProcessorApprovalCode>TEST</ProcessorApprovalCode><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved | </ResultDetail></Result></CreditSale_SoapResult></CreditSale_SoapResponse></soap:Body></soap:Envelope>"
read 671 bytes
Conn close
    XML
  end

  def successful_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditSale_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditSale_SoapResult><MCSTransactionID>886403</MCSTransactionID><ProcessorTransactionID>505995028</ProcessorTransactionID><Amount>1.00</Amount><TicketNumber /><ReferenceNumber /><ProcessorApprovalCode>TEST</ProcessorApprovalCode><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved | </ResultDetail></Result></CreditSale_SoapResult></CreditSale_SoapResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditSale_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditSale_SoapResult><MCSTransactionID>886436</MCSTransactionID><ProcessorTransactionID>506000356</ProcessorTransactionID><Amount>1.00</Amount><TicketNumber /><ReferenceNumber /><ProcessorApprovalCode /><Result><ResultCode>1</ResultCode><ResultDetail>50: General Decline | Invalid Expiration Date</ResultDetail></Result></CreditSale_SoapResult></CreditSale_SoapResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_void_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditVoid_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditVoid_SoapResult><MCSTransactionID>887159</MCSTransactionID><ProcessorTransactionID>506519784</ProcessorTransactionID><Amount>1.0000</Amount><TicketNumber /><ReferenceNumber>887158</ReferenceNumber><ProcessorApprovalCode>TEST</ProcessorApprovalCode><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved | </ResultDetail></Result></CreditVoid_SoapResult></CreditVoid_SoapResponse></soap:Body></soap:Envelope
    )
  end

  def successful_refund_response
    %(
      <?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditCredit_SoapResponse xmlns=\"https://MyCardStorage.com/\"><CreditCredit_SoapResult><MCSTransactionID>887156</MCSTransactionID><ProcessorTransactionID>506519720</ProcessorTransactionID><Amount>1.00</Amount><TicketNumber /><ReferenceNumber>887155</ReferenceNumber><ProcessorApprovalCode>TEST</ProcessorApprovalCode><Result><ResultCode>0</ResultCode><ResultDetail>0: Approved | </ResultDetail></Result></CreditCredit_SoapResult></CreditCredit_SoapResponse></soap:Body></soap:Envelope>
    )
  end

end
