require 'test_helper'

class VancoTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = VancoGateway.new(user_id: 'login', password: 'password', client_id: 'client_id')
    @credit_card = credit_card
    @check = check
    @amount = 100
    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_login_response, successful_purchase_response)

    assert_success response
    assert_equal '14949117|15756594|16136938', response.authorization
    assert_equal "Success", response.message
    assert response.test?
  end

  def test_successful_purchase_with_fund_id
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(fund_id: "MyEggcellentFund"))
    end.check_request do |endpoint, data, headers|
      if data =~ /<RequestType>EFTAdd/
        assert_match(%r(<FundID>MyEggcellentFund<\/FundID>), data)
      end
    end.respond_with(successful_login_response, successful_purchase_with_fund_id_response)

    assert_success response
    assert_equal '14949117|15756594|16137331', response.authorization
    assert_equal "Success", response.message
  end

  def test_successful_purchase_with_ip_address
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ip: "192.168.0.1"))
    end.check_request do |endpoint, data, headers|
      if data =~ /<RequestType>EFTAdd/
        assert_match(%r(<CustomerIPAddress>192), data)
      end
    end.respond_with(successful_login_response, successful_purchase_response)
    assert_success response
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_login_response, failed_purchase_response)

    assert_failure response
    assert_equal "286", response.params["error_codes"]
  end

  def test_failed_purchase_multiple_errors
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_login_response, failed_purchase_multiple_errors_response)

    assert_failure response
    assert_equal "Client not set up for International Credit Card Processing. Another Error.", response.message
    assert_equal "286, 331", response.params["error_codes"]
  end

  def test_successful_purchase_echeck
    response = stub_comms do
      @gateway.purchase(@amount, @check, @options)
    end.respond_with(successful_login_response, successful_purchase_echeck_response)

    assert_success response
    assert_equal '14949514|15757035|16138421', response.authorization
    assert_equal "Success", response.message
    assert response.test?
  end

  def test_failed_purchase_echeck
    response = stub_comms do
      @gateway.purchase(@amount, @check, @options)
    end.respond_with(successful_login_response, failed_purchase_echeck_response)

    assert_failure response
    assert_equal "178", response.params["error_codes"]
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, "authoriziation")
    end.respond_with(successful_login_response, successful_refund_response)

    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(@amount, "authorization")
    end.respond_with(successful_login_response, failed_refund_response)

    assert_failure response
    assert_equal "575", response.params["error_codes"]
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      <- "<?xml version=\"1.0\"?>\n<VancoWS>\n  <Auth>\n    <RequestType>Login</RequestType>\n    <RequestID>5464bab3283f1da7d123d3a5030f99</RequestID>\n    <RequestTime>2015-05-01 14:04:52 -0400</RequestTime>\n    <Version>2</Version>\n  </Auth>\n  <Request>\n    <RequestVars>\n      <UserID>SPREEDWS</UserID>\n      <Password>v@nco2oo</Password>\n    </RequestVars>\n  </Request>\n</VancoWS>\n"
      <- "POST /cgi-bin/wstest2.vps HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.vancodev.com\r\nContent-Length: 1194\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<VancoWS>\n  <Auth>\n    <RequestType>EFTAddCompleteTransaction</RequestType>\n    <RequestID>70b35fa8fa2ac3efb0c672fb3936a4</RequestID>\n    <RequestTime>2015-05-01 14:04:52 -0400</RequestTime>\n    <SessionID>c6bd084a24bd1898c5465a468282055f3807526c</SessionID>\n    <Version>2</Version>\n  </Auth>\n  <Request>\n    <RequestVars>\n      <ClientID>SPREEDLY</ClientID>\n      <AccountType>CC</AccountType>\n      <Amount>100.05</Amount>\n      <AccountNumber>4111111111111111</AccountNumber>\n      <TransactionTypeCode>WEB</TransactionTypeCode>\n      <CustomerName>Longsen, Longbob</CustomerName>\n      <CardExpMonth>09</CardExpMonth>\n      <CardExpYear>16</CardExpYear>\n      <CardCVV2>123</CardCVV2>\n      <CardBillingName>Longbob Longsen</CardBillingName>\n      <CardBillingAddr1>456 My Street</CardBillingAddr1>\n      <CardBillingAddr2>Apt 1</CardBillingAddr2>\n      <CardBillingCity>Ottawa</CardBillingCity>\n      <CardBillingState>NC</CardBillingState>\n      <CardBillingZip>06085</CardBillingZip>\n      <CardBillingCountryCode>US</CardBillingCountryCode>\n      <StartDate>0000-00-00</StartDate>\n      <FrequencyCode>O</FrequencyCode>\n    </RequestVars>\n  </Request>\n</VancoWS>\n"
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      <- "<?xml version=\"1.0\"?>\n<VancoWS>\n  <Auth>\n    <RequestType>Login</RequestType>\n    <RequestID>5464bab3283f1da7d123d3a5030f99</RequestID>\n    <RequestTime>2015-05-01 14:04:52 -0400</RequestTime>\n    <Version>2</Version>\n  </Auth>\n  <Request>\n    <RequestVars>\n      <UserID>SPREEDWS</UserID>\n      <Password>[FILTERED]</Password>\n    </RequestVars>\n  </Request>\n</VancoWS>\n"
      <- "POST /cgi-bin/wstest2.vps HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.vancodev.com\r\nContent-Length: 1194\r\n\r\n"
      <- "<?xml version=\"1.0\"?>\n<VancoWS>\n  <Auth>\n    <RequestType>EFTAddCompleteTransaction</RequestType>\n    <RequestID>70b35fa8fa2ac3efb0c672fb3936a4</RequestID>\n    <RequestTime>2015-05-01 14:04:52 -0400</RequestTime>\n    <SessionID>c6bd084a24bd1898c5465a468282055f3807526c</SessionID>\n    <Version>2</Version>\n  </Auth>\n  <Request>\n    <RequestVars>\n      <ClientID>SPREEDLY</ClientID>\n      <AccountType>CC</AccountType>\n      <Amount>100.05</Amount>\n      <AccountNumber>[FILTERED]</AccountNumber>\n      <TransactionTypeCode>WEB</TransactionTypeCode>\n      <CustomerName>Longsen, Longbob</CustomerName>\n      <CardExpMonth>09</CardExpMonth>\n      <CardExpYear>16</CardExpYear>\n      <CardCVV2>[FILTERED]</CardCVV2>\n      <CardBillingName>Longbob Longsen</CardBillingName>\n      <CardBillingAddr1>456 My Street</CardBillingAddr1>\n      <CardBillingAddr2>Apt 1</CardBillingAddr2>\n      <CardBillingCity>Ottawa</CardBillingCity>\n      <CardBillingState>NC</CardBillingState>\n      <CardBillingZip>06085</CardBillingZip>\n      <CardBillingCountryCode>US</CardBillingCountryCode>\n      <StartDate>0000-00-00</StartDate>\n      <FrequencyCode>O</FrequencyCode>\n    </RequestVars>\n  </Request>\n</VancoWS>\n"
    POST_SCRUBBED
  end

  def successful_login_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>fa031c3a937c1749bcbccc920d88e0</RequestID><RequestTime>2015-05-01 16:08:07 -0400</RequestTime><RequestType>Login</RequestType><Version>2</Version></Auth><Response><SessionID>5d8b104c9d8265db46bdf35ae9685472f4789dc8</SessionID></Response></VancoWS>
     )
  end

  def successful_purchase_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>ad4cbab9740e909423a02e622689d6</RequestID><RequestTime>2015-05-01 16:08:07 -0400</RequestTime><RequestType>EFTAddCompleteTransaction</RequestType><Signature></Signature><SessionID>5d8b104c9d8265db46bdf35ae9685472f4789dc8</SessionID><Version>2</Version></Auth><Response><StartDate>2015-05-01</StartDate><CustomerRef>14949117</CustomerRef><PaymentMethodRef>15756594</PaymentMethodRef><TransactionRef>16136938</TransactionRef><TransactionFee>3.20</TransactionFee></Response></VancoWS>
     )
  end

  def successful_purchase_with_fund_id_response
    %(
      <?xml version=\"1.0\" encoding=\"UTF-8\"  ?><VancoWS><Auth><RequestID>8cf42301416298c9d6d71a39b27a0d</RequestID><RequestTime>2015-05-05 15:45:57 -0400</RequestTime><RequestType>EFTAddCompleteTransaction</RequestType><Signature></Signature><SessionID>b2ec96e366f38a5c1ecd3f5343475526beaba4f9</SessionID><Version>2</Version></Auth><Response><StartDate>2015-05-05</StartDate><CustomerRef>14949117</CustomerRef><PaymentMethodRef>15756594</PaymentMethodRef><TransactionRef>16137331</TransactionRef><TransactionFee>3.20</TransactionFee></Response></VancoWS>\n\n
     )
  end

  def successful_purchase_echeck_response
    %(
      <?xml version=\"1.0\" encoding=\"UTF-8\"  ?><VancoWS><Auth><RequestID>186f2495a292b62a32435fcb8cd869</RequestID><RequestTime>2015-05-14 15:52:09 -0400</RequestTime><RequestType>EFTAddCompleteTransaction</RequestType><Signature></Signature><SessionID>38b674bb2301c570a6034c10488cc59ba5b2f9f7</SessionID><Version>2</Version></Auth><Response><StartDate>2015-05-18</StartDate><CustomerRef>14949514</CustomerRef><PaymentMethodRef>15757035</PaymentMethodRef><TransactionRef>16138421</TransactionRef><TransactionFee></TransactionFee></Response></VancoWS>\n\n
     )
  end

  def failed_purchase_echeck_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>e010cc92dfe411212d7b19c8100ff2</RequestID><RequestTime>2015-05-14 15:56:10 -0400</RequestTime><RequestType>EFTAddCompleteTransaction</RequestType><Signature></Signature><SessionID>160f8eee46ed4683a08cc3009dd19beada6ed225</SessionID><Version>2</Version></Auth><Response><Errors><Error><ErrorCode>178</ErrorCode><ErrorDescription>Invalid Routing Number</ErrorDescription></Error></Errors></Response></VancoWS>
     )
  end

  def failed_purchase_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>8fde1fc5f27a09eeafffe8761c546c</RequestID><RequestTime>2015-05-01 16:13:34 -0400</RequestTime><RequestType>EFTAddCompleteTransaction</RequestType><Signature></Signature><SessionID>ae3a84a0963b83eeb44db13027e37f172e24d939</SessionID><Version>2</Version></Auth><Response><Errors><Error><ErrorCode>286</ErrorCode><ErrorDescription>Client not set up for International Credit Card Processing</ErrorDescription></Error></Errors></Response></VancoWS>
     )
  end

  def failed_purchase_multiple_errors_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?> <VancoWS> <Auth> <RequestID> 8fde1fc5f27a09eeafffe8761c546c</RequestID> <RequestTime> 2015-05-01 16:13:34 -0400</RequestTime> <RequestType> EFTAddCompleteTransaction</RequestType> <Signature> </Signature> <SessionID> ae3a84a0963b83eeb44db13027e37f172e24d939</SessionID> <Version> 2</Version> </Auth> <Response> <Errors> <Error> <ErrorCode>286</ErrorCode> <ErrorDescription>Client not set up for International Credit Card Processing</ErrorDescription> </Error> <Error> <ErrorCode>331</ErrorCode> <ErrorDescription>Another Error</ErrorDescription> </Error> </Errors> </Response> </VancoWS>
     )
  end

  def successful_refund_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>bca6411369a25f9fe9329f7f6c3f1d</RequestID><RequestTime>2015-05-01 16:18:33 -0400</RequestTime><RequestType>EFTAddCredit</RequestType><Signature></Signature><SessionID>32bed62d469e6ee4e92a5d2c56a77d1dea149a6e</SessionID><Version>2</Version></Auth><Response><CreditRequestReceived>Yes</CreditRequestReceived></Response></VancoWS>
     )
  end

  def failed_refund_response
    %(
      <?xml version="1.0" encoding="UTF-8"  ?><VancoWS><Auth><RequestID>dc9a5e2b620eee5d248e1b33cc1f33</RequestID><RequestTime>2015-05-01 16:19:33 -0400</RequestTime><RequestType>EFTAddCredit</RequestType><Signature></Signature><SessionID>67a731057f821413155033bc23551aef3ba0b204</SessionID><Version>2</Version></Auth><Response><Errors><Error><ErrorCode>575</ErrorCode><ErrorDescription>Amount Cannot Be Greater Than $100.05</ErrorDescription></Error></Errors></Response></VancoWS>
     )
  end

end
