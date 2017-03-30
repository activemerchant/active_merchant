require 'test_helper'

class CharityEngineTest < Test::Unit::TestCase
  def setup
    @gateway = CharityEngineGateway.new(username: 'login', password: 'password')
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

    assert_equal '42804774', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Expired Card', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-XML
opening connection to api.charityengine.net:443...
opened
starting SSL for api.charityengine.net:443...
SSL established
<- "POST /api.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://api.bisglobal.net/ChargeCreditCard\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.charityengine.net\r\nContent-Length: 1476\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Body>\n    <ChargeCreditCard xmlns=\"https://api.bisglobal.net/\">\n      <credentials>\n        <Username>foo</Username>\n        <Password>bar</Password>\n        <AuthenticationType>WebServiceUser</AuthenticationType>\n      </credentials>\n      <parameters>\n        <Charges>\n          <ChargeCreditCardParameters>\n            <Amount>1.00</Amount>\n            <TaxDeductibleAmount>1.00</TaxDeductibleAmount>\n            <BillingAddressStreet1>456 My Street</BillingAddressStreet1>\n            <BillingAddressStreet2>Apt 1</BillingAddressStreet2>\n            <BillingAddressCity>Ottawa</BillingAddressCity>\n            <BillingAddressStateProvince>ON</BillingAddressStateProvince>\n            <BillingAddressPostalCode>K1C2N6</BillingAddressPostalCode>\n            <CreditCardInfo>\n              <CreditCardNumber>4000100011112224</CreditCardNumber>\n              <CreditCardExpirationMonth>09</CreditCardExpirationMonth>\n              <CreditCardExpirationYear>2018</CreditCardExpirationYear>\n              <CreditCardNameOnCard>Longbob Longsen</CreditCardNameOnCard>\n            </CreditCardInfo>\n          </ChargeCreditCardParameters>\n        </Charges>\n      </parameters>\n    </ChargeCreditCard>\n  </soap12:Body>\n</soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 27 Mar 2017 00:10:38 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 1375\r\n"
-> "\r\n"
reading 1375 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\r\n  <soap:Body>\r\n    <ChargeCreditCardResponse xmlns=\"https://api.bisglobal.net/\">\r\n      <ChargeCreditCardResult>\r\n        <Successful>true</Successful>\r\n        <Record_Id>0</Record_Id>\r\n        <RecordIdList>\r\n          <long>42782466</long>\r\n        </RecordIdList>\r\n        <ErrorMessage>\r\n          <Code>0</Code>\r\n          <Description />\r\n        </ErrorMessage>\r\n        <QueryRecordCount>0</QueryRecordCount>\r\n        <RecordsAffected>1</RecordsAffected>\r\n        <Charges>\r\n          <TransactionDetail>\r\n            <Successful>true</Successful>\r\n            <Record_Id>0</Record_Id>\r\n            <RecordIdList />\r\n            <ErrorMessage>\r\n              <Code>0</Code>\r\n              <Description />\r\n            </ErrorMessage>\r\n            <QueryRecordCount>0</QueryRecordCount>\r\n            <RecordsAffected>0</RecordsAffected>\r\n            <Transaction_Id>42782466</Transaction_Id>\r\n            <PaymentSuccessful>false</PaymentSuccessful>\r\n            <DeclineDetails>Declined</DeclineDetails>\r\n          </TransactionDetail>\r\n        </Charges>\r\n      </ChargeCreditCardResult>\r\n    </ChargeCreditCardResponse>\r\n  </soap:Body>\r\n</soap:Envelope>\r\n"
read 1375 bytes
Conn close
    XML
  end

  def post_scrubbed
    <<-XML
opening connection to api.charityengine.net:443...
opened
starting SSL for api.charityengine.net:443...
SSL established
<- "POST /api.asmx HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: https://api.bisglobal.net/ChargeCreditCard\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.charityengine.net\r\nContent-Length: 1476\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n  <soap12:Body>\n    <ChargeCreditCard xmlns=\"https://api.bisglobal.net/\">\n      <credentials>\n        <Username>[FILTERED]</Username>\n        <Password>[FILTERED]</Password>\n        <AuthenticationType>WebServiceUser</AuthenticationType>\n      </credentials>\n      <parameters>\n        <Charges>\n          <ChargeCreditCardParameters>\n            <Amount>1.00</Amount>\n            <TaxDeductibleAmount>1.00</TaxDeductibleAmount>\n            <BillingAddressStreet1>456 My Street</BillingAddressStreet1>\n            <BillingAddressStreet2>Apt 1</BillingAddressStreet2>\n            <BillingAddressCity>Ottawa</BillingAddressCity>\n            <BillingAddressStateProvince>ON</BillingAddressStateProvince>\n            <BillingAddressPostalCode>K1C2N6</BillingAddressPostalCode>\n            <CreditCardInfo>\n              <CreditCardNumber>[FILTERED]</CreditCardNumber>\n              <CreditCardExpirationMonth>09</CreditCardExpirationMonth>\n              <CreditCardExpirationYear>2018</CreditCardExpirationYear>\n              <CreditCardNameOnCard>Longbob Longsen</CreditCardNameOnCard>\n            </CreditCardInfo>\n          </ChargeCreditCardParameters>\n        </Charges>\n      </parameters>\n    </ChargeCreditCard>\n  </soap12:Body>\n</soap12:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: application/soap+xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 27 Mar 2017 00:10:38 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 1375\r\n"
-> "\r\n"
reading 1375 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\r\n  <soap:Body>\r\n    <ChargeCreditCardResponse xmlns=\"https://api.bisglobal.net/\">\r\n      <ChargeCreditCardResult>\r\n        <Successful>true</Successful>\r\n        <Record_Id>0</Record_Id>\r\n        <RecordIdList>\r\n          <long>42782466</long>\r\n        </RecordIdList>\r\n        <ErrorMessage>\r\n          <Code>0</Code>\r\n          <Description />\r\n        </ErrorMessage>\r\n        <QueryRecordCount>0</QueryRecordCount>\r\n        <RecordsAffected>1</RecordsAffected>\r\n        <Charges>\r\n          <TransactionDetail>\r\n            <Successful>true</Successful>\r\n            <Record_Id>0</Record_Id>\r\n            <RecordIdList />\r\n            <ErrorMessage>\r\n              <Code>0</Code>\r\n              <Description />\r\n            </ErrorMessage>\r\n            <QueryRecordCount>0</QueryRecordCount>\r\n            <RecordsAffected>0</RecordsAffected>\r\n            <Transaction_Id>42782466</Transaction_Id>\r\n            <PaymentSuccessful>false</PaymentSuccessful>\r\n            <DeclineDetails>Declined</DeclineDetails>\r\n          </TransactionDetail>\r\n        </Charges>\r\n      </ChargeCreditCardResult>\r\n    </ChargeCreditCardResponse>\r\n  </soap:Body>\r\n</soap:Envelope>\r\n"
read 1375 bytes
Conn close
    XML
  end

  def successful_purchase_response
    %(<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\r\n  <soap:Body>\r\n    <ChargeCreditCardResponse xmlns=\"https://api.bisglobal.net/\">\r\n      <ChargeCreditCardResult>\r\n        <Successful>true</Successful>\r\n        <Record_Id>0</Record_Id>\r\n        <RecordIdList>\r\n          <long>42804774</long>\r\n        </RecordIdList>\r\n        <ErrorMessage>\r\n          <Code>0</Code>\r\n          <Description />\r\n        </ErrorMessage>\r\n        <QueryRecordCount>0</QueryRecordCount>\r\n        <RecordsAffected>1</RecordsAffected>\r\n        <Charges>\r\n          <TransactionDetail>\r\n            <Successful>true</Successful>\r\n            <Record_Id>0</Record_Id>\r\n            <RecordIdList />\r\n            <ErrorMessage>\r\n              <Code>0</Code>\r\n              <Description />\r\n            </ErrorMessage>\r\n            <QueryRecordCount>0</QueryRecordCount>\r\n            <RecordsAffected>0</RecordsAffected>\r\n            <Transaction_Id>42804774</Transaction_Id>\r\n            <PaymentSuccessful>true</PaymentSuccessful>\r\n            <DeclineDetails />\r\n          </TransactionDetail>\r\n        </Charges>\r\n      </ChargeCreditCardResult>\r\n    </ChargeCreditCardResponse>\r\n  </soap:Body>\r\n</soap:Envelope>\r\n)
  end

  def failed_purchase_response
    %(<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\r\n  <soap:Body>\r\n    <ChargeCreditCardResponse xmlns=\"https://api.bisglobal.net/\">\r\n      <ChargeCreditCardResult>\r\n        <Successful>true</Successful>\r\n        <Record_Id>0</Record_Id>\r\n        <RecordIdList>\r\n          <long>42798609</long>\r\n        </RecordIdList>\r\n        <ErrorMessage>\r\n          <Code>0</Code>\r\n          <Description />\r\n        </ErrorMessage>\r\n        <QueryRecordCount>0</QueryRecordCount>\r\n        <RecordsAffected>1</RecordsAffected>\r\n        <Charges>\r\n          <TransactionDetail>\r\n            <Successful>true</Successful>\r\n            <Record_Id>0</Record_Id>\r\n            <RecordIdList />\r\n            <ErrorMessage>\r\n              <Code>0</Code>\r\n              <Description />\r\n            </ErrorMessage>\r\n            <QueryRecordCount>0</QueryRecordCount>\r\n            <RecordsAffected>0</RecordsAffected>\r\n            <Transaction_Id>42798609</Transaction_Id>\r\n            <PaymentSuccessful>false</PaymentSuccessful>\r\n            <DeclineDetails>Expired Card</DeclineDetails>\r\n          </TransactionDetail>\r\n        </Charges>\r\n      </ChargeCreditCardResult>\r\n    </ChargeCreditCardResponse>\r\n  </soap:Body>\r\n</soap:Envelope>\r\n)
  end

end
