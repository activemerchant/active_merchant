require 'test_helper'

class IridiumTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = IridiumGateway.new(:login => 'login', :password => 'password')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1;100115170338509401960011;960011', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end


  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal('1;100115172046327701460093;460093', response.authorization)
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(1111, "1;100115172046327701460093;460093")
    assert_success response

    assert_equal('100115172047506301812526', response.authorization)
    assert response.test?
  end

  def test_successful_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      assert response = @gateway.credit(@amount, '123456789')
      assert_success response
      assert_equal 'Refund successful', response.message
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.refund(@amount, '123456789')
    assert_success response
    assert_equal 'Refund successful', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert response = @gateway.refund(@amount, '123456789')
    assert_failure response
    assert_equal 'Amount exceeds that available for refund [17]', response.message
  end

  def test_default_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/CurrencyCode="978"/), anything).returns(successful_purchase_response)
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_override_currency
    @gateway.expects(:ssl_post).
      with(anything, all_of(regexp_matches(/Amount="400"/), regexp_matches(/CurrencyCode="484"/)), anything).
      returns(successful_purchase_response)
    assert_success @gateway.purchase(400, @credit_card, @options.merge(:currency => 'MXN'))
  end

  def test_do_not_depend_on_expiry_date_class
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    @credit_card.expects(:expiry_date).never

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_use_ducktyping_for_credit_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    credit_card = stub(:number => '4242424242424242', :verification_value => '123', :name => "Hans Tester", :year => 2012, :month => 1)

    assert_nothing_raised do
      assert_success @gateway.purchase(@amount, credit_card, @options)
    end
  end


  def test_transcript_scrubbing
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end


  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CardDetailsTransactionResult AuthorisationAttempted="True">
              <StatusCode>0</StatusCode>
              <Message>AuthCode: 960011</Message>
            </CardDetailsTransactionResult>
            <TransactionOutputData CrossReference="100115170338509401960011">
              <AuthCode>960011</AuthCode>
              <AddressNumericCheckResult>PASSED</AddressNumericCheckResult>
              <PostCodeCheckResult>PASSED</PostCodeCheckResult>
              <CV2CheckResult>PASSED</CV2CheckResult>
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CardDetailsTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CardDetailsTransactionResult AuthorisationAttempted="True">
              <StatusCode>5</StatusCode>
              <Message>Card declined</Message>
            </CardDetailsTransactionResult>
            <TransactionOutputData CrossReference="100115170341897501476979">
              <AddressNumericCheckResult>NOT_SUBMITTED</AddressNumericCheckResult>
              <PostCodeCheckResult>NOT_SUBMITTED</PostCodeCheckResult>
              <CV2CheckResult>NOT_SUBMITTED</CV2CheckResult>
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CardDetailsTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_authorize_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CardDetailsTransactionResult AuthorisationAttempted="True">
              <StatusCode>0</StatusCode>
              <Message>AuthCode: 460093</Message>
            </CardDetailsTransactionResult>
            <TransactionOutputData CrossReference="100115172046327701460093">
              <AuthCode>460093</AuthCode>
              <AddressNumericCheckResult>PASSED</AddressNumericCheckResult>
              <PostCodeCheckResult>PASSED</PostCodeCheckResult>
              <CV2CheckResult>PASSED</CV2CheckResult>
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CardDetailsTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_capture_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CrossReferenceTransactionResult AuthorisationAttempted="True">
              <StatusCode>0</StatusCode>
              <Message>Collection successful</Message>
            </CrossReferenceTransactionResult>
            <TransactionOutputData CrossReference="100115172047506301812526">
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CrossReferenceTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def successful_credit_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CrossReferenceTransactionResult AuthorisationAttempted="True">
              <StatusCode>0</StatusCode>
              <Message>Refund successful</Message>
            </CrossReferenceTransactionResult>
            <TransactionOutputData CrossReference="100115191230621201758765">
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CrossReferenceTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def failed_credit_response
    %(<?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <CrossReferenceTransactionResponse xmlns="https://www.thepaymentgateway.net/">
            <CrossReferenceTransactionResult AuthorisationAttempted="False">
              <StatusCode>30</StatusCode>
              <Message>Amount exceeds that available for refund [17]</Message>
            </CrossReferenceTransactionResult>
            <TransactionOutputData CrossReference="100115191228938501632678">
              <GatewayEntryPoints>
                <GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" />
                <GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" />
                <GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" />
              </GatewayEntryPoints>
            </TransactionOutputData>
          </CrossReferenceTransactionResponse>
        </soap:Body>
      </soap:Envelope>)
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soap:Body>
    <CardDetailsTransaction xmlns="https://www.thepaymentgateway.net/">
      <PaymentMessage>
        <MerchantAuthentication MerchantID="Flamen-3258723" Password="7C03L5ON49"/>
        <TransactionDetails Amount="100" CurrencyCode="978">
          <MessageDetails TransactionType="SALE"/>
          <OrderID>c7073e2a2d18b19b8dadcd0a5da3f7e1</OrderID>
          <TransactionControl>
            <ThreeDSecureOverridePolicy>FALSE</ThreeDSecureOverridePolicy>
            <EchoAVSCheckResult>TRUE</EchoAVSCheckResult>
            <EchoCV2CheckResult>TRUE</EchoCV2CheckResult>
          </TransactionControl>
        </TransactionDetails>
        <CardDetails>
          <CardName>Longbob Longsen</CardName>
          <CV2>452</CV2>
          <CardNumber>4976000000003436</CardNumber>
          <ExpiryDate Month="09" Year="12"/>
        </CardDetails>
        <CustomerDetails>
          <BillingAddress>
            <Address1>32 Edward Street</Address1>
            <Address2>Camborne</Address2>
            <City>Ottawa</City>
            <State>Cornwall</State>
            <PostCode>TR14&#160;8PA</PostCode>
            <CountryCode>826</CountryCode>
          </BillingAddress>
          <PhoneNumber>(555)555-5555</PhoneNumber>
          <EmailAddress></EmailAddress>
          <CustomerIPAddress>127.0.0.1</CustomerIPAddress>
        </CustomerDetails>
      </PaymentMessage>
    </CardDetailsTransaction>
  </soap:Body>
  </soap:Envelope>
  <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/"><CardDetailsTransactionResult AuthorisationAttempted="True"><StatusCode>0</StatusCode><Message>AuthCode: 608724</Message></CardDetailsTransactionResult><TransactionOutputData CrossReference="110428221508160201608724"><AuthCode>608724</AuthCode><AddressNumericCheckResult>PASSED</AddressNumericCheckResult><PostCodeCheckResult>PASSED</PostCodeCheckResult><CV2CheckResult>PASSED</CV2CheckResult><GatewayEntryPoints><GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" /><GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" /><GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" /></GatewayEntryPoints></TransactionOutputData></CardDetailsTransactionResponse></soap:Body></soap:Envelope>
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soap:Body>
    <CardDetailsTransaction xmlns="https://www.thepaymentgateway.net/">
      <PaymentMessage>
        <MerchantAuthentication MerchantID="Flamen-3258723" Password="7C03L5ON49"/>
        <TransactionDetails Amount="100" CurrencyCode="978">
          <MessageDetails TransactionType="SALE"/>
          <OrderID>c7073e2a2d18b19b8dadcd0a5da3f7e1</OrderID>
          <TransactionControl>
            <ThreeDSecureOverridePolicy>FALSE</ThreeDSecureOverridePolicy>
            <EchoAVSCheckResult>TRUE</EchoAVSCheckResult>
            <EchoCV2CheckResult>TRUE</EchoCV2CheckResult>
          </TransactionControl>
        </TransactionDetails>
        <CardDetails>
          <CardName>Longbob Longsen</CardName>
          <CV2>[FILTERED]</CV2>
          <CardNumber>[FILTERED]</CardNumber>
          <ExpiryDate Month="09" Year="12"/>
        </CardDetails>
        <CustomerDetails>
          <BillingAddress>
            <Address1>32 Edward Street</Address1>
            <Address2>Camborne</Address2>
            <City>Ottawa</City>
            <State>Cornwall</State>
            <PostCode>TR14&#160;8PA</PostCode>
            <CountryCode>826</CountryCode>
          </BillingAddress>
          <PhoneNumber>(555)555-5555</PhoneNumber>
          <EmailAddress></EmailAddress>
          <CustomerIPAddress>127.0.0.1</CustomerIPAddress>
        </CustomerDetails>
      </PaymentMessage>
    </CardDetailsTransaction>
  </soap:Body>
  </soap:Envelope>
  <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CardDetailsTransactionResponse xmlns="https://www.thepaymentgateway.net/"><CardDetailsTransactionResult AuthorisationAttempted="True"><StatusCode>0</StatusCode><Message>AuthCode: 608724</Message></CardDetailsTransactionResult><TransactionOutputData CrossReference="110428221508160201608724"><AuthCode>608724</AuthCode><AddressNumericCheckResult>PASSED</AddressNumericCheckResult><PostCodeCheckResult>PASSED</PostCodeCheckResult><CV2CheckResult>PASSED</CV2CheckResult><GatewayEntryPoints><GatewayEntryPoint EntryPointURL="https://gw1.iridiumcorp.net/" Metric="100" /><GatewayEntryPoint EntryPointURL="https://gw2.iridiumcorp.net/" Metric="200" /><GatewayEntryPoint EntryPointURL="https://gw3.iridiumcorp.net/" Metric="300" /></GatewayEntryPoints></TransactionOutputData></CardDetailsTransactionResponse></soap:Body></soap:Envelope>
    POST_SCRUBBED
  end

end
