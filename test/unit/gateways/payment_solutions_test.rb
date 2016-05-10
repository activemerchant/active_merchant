require 'test_helper'

class PaymentSolutionsTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentSolutionsGateway.new(username: 'login', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '2',
      billing_address: address({
        city:     'Hollywood',
        state:    'CA',
        zip:      '90210',
        country:  'USA',}),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '000000', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'This transaction has been declined.', response.message
  end


  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-eos
      opening connection to staging.paymentsolutionsinc.net:443...
      opened
      starting SSL for staging.paymentsolutionsinc.net:443...
      SSL established
      <- "POST /Services/Aspca/Payment/PsiWcfService.svc HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: http://www.paymentsolutionsinc.net/IPsiService/SendCreditCardPayment\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: staging.paymentsolutionsinc.net\r\nContent-Length: 1768\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Body>\n    <SendCreditCardPayment xmlns=\"http://www.paymentsolutionsinc.net/\">\n      <credentials xmlns:d4p1=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\">\n        <d4p1:Password>password</d4p1:Password>\n        <d4p1:UserName>login</d4p1:UserName>\n      </credentials>\n      <paymentInfo xmlns:d4p1=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\">\n        <d4p1:Amount>0.01</d4p1:Amount>\n        <d4p1:ClientTransactionId>1</d4p1:ClientTransactionId>\n        <d4p1:CreditCard>\n          <d4p1:CardNo>4111111111111111</d4p1:CardNo>\n          <d4p1:ExpMonth>05</d4p1:ExpMonth>\n          <d4p1:ExpYear>2017</d4p1:ExpYear>\n          <d4p1:Cvv>111</d4p1:Cvv>\n          <d4p1:Type>Visa</d4p1:Type>\n        </d4p1:CreditCard>\n        <d4p1:Donor>\n          <d4p1:Address1>street</d4p1:Address1>\n          <d4p1:City>some city</d4p1:City>\n          <d4p1:Employer/>\n          <d4p1:FirstName>Foo</d4p1:FirstName>\n          <d4p1:LastName>Bar</d4p1:LastName>\n          <d4p1:Phone>N/A</d4p1:Phone>\n          <d4p1:PostalCode>90210</d4p1:PostalCode>\n          <d4p1:SendEmail>false</d4p1:SendEmail>\n          <d4p1:StateProvince>a province of sorts</d4p1:StateProvince>\n          <d4p1:Address2>foo</d4p1:Address2>\n          <d4p1:Country>USA</d4p1:Country>\n        </d4p1:Donor>\n        <d4p1:Frequency>Monthly</d4p1:Frequency>\n        <d4p1:PayType>OneTime</d4p1:PayType>\n        <d4p1:ProcessDateTime>2016-05-10T14:34:23</d4p1:ProcessDateTime>\n      </paymentInfo>\n    </SendCreditCardPayment>\n  </s:Body>\n</s:Envelope>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Length: 876\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Tue, 10 May 2016 04:34:24 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 876 bytes...
      -> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><SendCreditCardPaymentResponse xmlns=\"http://www.paymentsolutionsinc.net/\"><SendCreditCardPaymentResult xmlns:a=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><a:AmountApproved>0.01</a:AmountApproved><a:Approved>true</a:Approved><a:AuthorizationCode>000000</a:AuthorizationCode><a:ClientTransactionId>922241624</a:ClientTransactionId><a:GatewayRawResponse i:nil=\"true\"/><a:ProcessedDateTime>2016-05-10T00:34:24.7814177-04:00</a:ProcessedDateTime><a:ReasonCode>1</a:ReasonCode><a:ResponseCode>1</a:ResponseCode><a:ResponseMessage>This transaction has been approved.</a:ResponseMessage><a:ResponseTime>1185.6021</a:ResponseTime><a:TransactionId>0</a:TransactionId></SendCreditCardPaymentResult></SendCreditCardPaymentResponse></s:Body></s:Envelope>"
      read 876 bytes
      Conn close
    eos
  end

  def post_scrubbed
    <<-eos
      opening connection to staging.paymentsolutionsinc.net:443...
      opened
      starting SSL for staging.paymentsolutionsinc.net:443...
      SSL established
      <- "POST /Services/Aspca/Payment/PsiWcfService.svc HTTP/1.1\r\nContent-Type: text/xml\r\nSoapaction: http://www.paymentsolutionsinc.net/IPsiService/SendCreditCardPayment\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: staging.paymentsolutionsinc.net\r\nContent-Length: 1768\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <s:Body>\n    <SendCreditCardPayment xmlns=\"http://www.paymentsolutionsinc.net/\">\n      <credentials xmlns:d4p1=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\">\n        <d4p1:Password>[FILTERED]</d4p1:Password>\n        <d4p1:UserName>[FILTERED]</d4p1:UserName>\n      </credentials>\n      <paymentInfo xmlns:d4p1=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\">\n        <d4p1:Amount>0.01</d4p1:Amount>\n        <d4p1:ClientTransactionId>1</d4p1:ClientTransactionId>\n        <d4p1:CreditCard>\n          <d4p1:CardNo>[FILTERED]</d4p1:CardNo>\n          <d4p1:ExpMonth>05</d4p1:ExpMonth>\n          <d4p1:ExpYear>2017</d4p1:ExpYear>\n          <d4p1:Cvv>[FILTERED]</d4p1:Cvv>\n          <d4p1:Type>Visa</d4p1:Type>\n        </d4p1:CreditCard>\n        <d4p1:Donor>\n          <d4p1:Address1>street</d4p1:Address1>\n          <d4p1:City>some city</d4p1:City>\n          <d4p1:Employer/>\n          <d4p1:FirstName>Foo</d4p1:FirstName>\n          <d4p1:LastName>Bar</d4p1:LastName>\n          <d4p1:Phone>N/A</d4p1:Phone>\n          <d4p1:PostalCode>90210</d4p1:PostalCode>\n          <d4p1:SendEmail>false</d4p1:SendEmail>\n          <d4p1:StateProvince>a province of sorts</d4p1:StateProvince>\n          <d4p1:Address2>foo</d4p1:Address2>\n          <d4p1:Country>USA</d4p1:Country>\n        </d4p1:Donor>\n        <d4p1:Frequency>Monthly</d4p1:Frequency>\n        <d4p1:PayType>OneTime</d4p1:PayType>\n        <d4p1:ProcessDateTime>2016-05-10T14:34:23</d4p1:ProcessDateTime>\n      </paymentInfo>\n    </SendCreditCardPayment>\n  </s:Body>\n</s:Envelope>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Length: 876\r\n"
      -> "Content-Type: text/xml; charset=utf-8\r\n"
      -> "Server: Microsoft-IIS/7.5\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Tue, 10 May 2016 04:34:24 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 876 bytes...
      -> "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><SendCreditCardPaymentResponse xmlns=\"http://www.paymentsolutionsinc.net/\"><SendCreditCardPaymentResult xmlns:a=\"http://schemas.datacontract.org/2004/07/PsiService\" xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\"><a:AmountApproved>0.01</a:AmountApproved><a:Approved>true</a:Approved><a:AuthorizationCode>000000</a:AuthorizationCode><a:ClientTransactionId>922241624</a:ClientTransactionId><a:GatewayRawResponse i:nil=\"true\"/><a:ProcessedDateTime>2016-05-10T00:34:24.7814177-04:00</a:ProcessedDateTime><a:ReasonCode>1</a:ReasonCode><a:ResponseCode>1</a:ResponseCode><a:ResponseMessage>This transaction has been approved.</a:ResponseMessage><a:ResponseTime>1185.6021</a:ResponseTime><a:TransactionId>0</a:TransactionId></SendCreditCardPaymentResult></SendCreditCardPaymentResponse></s:Body></s:Envelope>"
      read 876 bytes
      Conn close
    eos

  end

  def successful_purchase_response
    <<-eos
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
          <SendCreditCardPaymentResponse xmlns="http://www.paymentsolutionsinc.net/">
            <SendCreditCardPaymentResult xmlns:a="http://schemas.datacontract.org/2004/07/PsiService" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
              <a:AmountApproved>1.00</a:AmountApproved>
              <a:Approved>true</a:Approved>
              <a:AuthorizationCode>000000</a:AuthorizationCode>
              <a:ClientTransactionId>922241628</a:ClientTransactionId>
              <a:GatewayRawResponse i:nil="true"/>
              <a:ProcessedDateTime>2016-05-10T00:41:14.9373381-04:00</a:ProcessedDateTime>
              <a:ReasonCode>1</a:ReasonCode>
              <a:ResponseCode>1</a:ResponseCode>
              <a:ResponseMessage>This transaction has been approved.</a:ResponseMessage>
              <a:ResponseTime>889.2015</a:ResponseTime>
              <a:TransactionId>0</a:TransactionId>
            </SendCreditCardPaymentResult>
          </SendCreditCardPaymentResponse>
        </s:Body>
      </s:Envelope>
    eos
  end

  def failed_purchase_response
    <<-eos
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
          <SendCreditCardPaymentResponse xmlns="http://www.paymentsolutionsinc.net/">
            <SendCreditCardPaymentResult xmlns:a="http://schemas.datacontract.org/2004/07/PsiService" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
              <a:AmountApproved>2.00</a:AmountApproved>
              <a:Approved>false</a:Approved>
              <a:AuthorizationCode>000000</a:AuthorizationCode>
              <a:ClientTransactionId>922241654</a:ClientTransactionId>
              <a:GatewayRawResponse i:nil="true"/>
              <a:ProcessedDateTime>2016-05-10T21:29:52.1657233-04:00</a:ProcessedDateTime>
              <a:ReasonCode>2</a:ReasonCode>
              <a:ResponseCode>2</a:ResponseCode>
              <a:ResponseMessage>This transaction has been declined.</a:ResponseMessage>
              <a:ResponseTime>842.4015</a:ResponseTime>
              <a:TransactionId>0</a:TransactionId>
            </SendCreditCardPaymentResult>
          </SendCreditCardPaymentResponse>
        </s:Body>
      </s:Envelope>
    eos
  end
end
