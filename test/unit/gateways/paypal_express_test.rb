require 'test_helper'

class PaypalExpressTest < Test::Unit::TestCase
  TEST_REDIRECT_URL        = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=1234567890'
  TEST_REDIRECT_URL_MOBILE = 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout-mobile&token=1234567890'
  LIVE_REDIRECT_URL        = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token=1234567890'
  LIVE_REDIRECT_URL_MOBILE = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout-mobile&token=1234567890'
  
  TEST_REDIRECT_URL_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL}&useraction=commit"
  LIVE_REDIRECT_URL_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL}&useraction=commit"
  TEST_REDIRECT_URL_MOBILE_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL_MOBILE}&useraction=commit"
  LIVE_REDIRECT_URL_MOBILE_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL_MOBILE}&useraction=commit"

  def setup
    @gateway = PaypalExpressGateway.new(
      :login => 'cody', 
      :password => 'test',
      :pem => 'PEM'
    )

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }

    Base.gateway_mode = :test
  end 
  
  def teardown
    Base.gateway_mode = :test
  end 

  def test_live_redirect_url
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal LIVE_REDIRECT_URL_MOBILE, @gateway.redirect_url_for('1234567890', :mobile => true)
  end

  def test_live_redirect_url_without_review
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
    assert_equal LIVE_REDIRECT_URL_MOBILE_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false, :mobile => true)
  end
  
  def test_force_sandbox_redirect_url
    Base.gateway_mode = :production
    
    gateway = PaypalExpressGateway.new(
      :login => 'cody', 
      :password => 'test',
      :pem => 'PEM',
      :test => true
    )
    
    assert gateway.test?
    assert_equal TEST_REDIRECT_URL, gateway.redirect_url_for('1234567890')
    assert_equal TEST_REDIRECT_URL_MOBILE, gateway.redirect_url_for('1234567890', :mobile => true)
  end
  
  def test_test_redirect_url
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
    assert_equal TEST_REDIRECT_URL_MOBILE, @gateway.redirect_url_for('1234567890', :mobile => true)
  end
  
  def test_test_redirect_url_without_review
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
    assert_equal TEST_REDIRECT_URL_MOBILE_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false, :mobile => true)
  end
  
  def test_get_express_details
    @gateway.expects(:ssl_post).returns(successful_details_response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
  
    assert_instance_of PaypalExpressResponse, response
    assert response.success?
    assert response.test?
    
    assert_equal 'EC-6WS104951Y388951L', response.token
    assert_equal 'FWRVKNRRZ3WUC', response.payer_id
    assert_equal 'buyer@jadedpallet.com', response.email
    
    assert address = response.address
    assert_equal 'Fred Brooks', address['name']
    assert_nil address['company']
    assert_equal '1234 Penny Lane', address['address1']
    assert_nil address['address2']
    assert_equal 'Jonsetown', address['city']
    assert_equal 'NC', address['state']
    assert_equal '23456', address['zip']
    assert_equal 'US', address['country']
    assert_nil address['phone']
  end
  
  def test_get_transaction_details
      @gateway.expects(:ssl_post).returns(successful_transaction_details_response)
      response = @gateway.transaction_details_for('1GR40996P1767570Y')
      
      assert_instance_of PaypalExpressResponse, response
      assert response.success?
      assert response.test?
      
      assert_equal '1GR40996P1767570Y', response.params['transaction_id']
      assert_equal 'EGURACDVJPULC', response.payer_id
      assert_equal 'test-sender@snaildeal.com', response.email
      assert_equal 'Refunded', response.params['payment_status']
      assert address = response.address
      assert_equal 'Test', response.params['first_name']
      assert_equal 'User', response.params['last_name']
      assert_nil address['name']
  end
  
  def test_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.authorize(300, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC')
    assert response.success?
    assert_not_nil response.authorization
    assert response.test?
  end
  
  def test_default_payflow_currency
    assert_equal 'USD', PayflowExpressGateway.default_currency
  end
  
  def test_default_partner
    assert_equal 'PayPal', PayflowExpressGateway.partner
  end
  
  def test_uk_partner
    assert_equal 'PayPalUk', PayflowExpressUkGateway.partner
  end
  
  def test_handle_non_zero_amount
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 50, {}))
    
    assert_equal '0.50', REXML::XPath.first(xml, '//n2:OrderTotal').text
  end
  
  def test_handles_zero_amount
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))
    
    assert_equal '1.00', REXML::XPath.first(xml, '//n2:OrderTotal').text
  end
  
  def test_amount_format_for_jpy_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/n2:OrderTotal currencyID=.JPY.>1<\/n2:OrderTotal>/)).returns(successful_authorization_response)
    response = @gateway.authorize(100, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC', :currency => 'JPY')
    assert response.success?
  end
  
  def test_handle_locale_code
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :locale => 'GB' }))
    
    assert_equal 'GB', REXML::XPath.first(xml, '//n2:LocaleCode').text
  end
  
  def test_supported_countries
    assert_equal ['US'], PaypalExpressGateway.supported_countries
  end
  
  def test_button_source
    PaypalExpressGateway.application_id = 'ActiveMerchant_EC'
    
    xml = REXML::Document.new(@gateway.send(:build_sale_or_authorization_request, 'Test', 100, {}))
    assert_equal 'ActiveMerchant_EC', REXML::XPath.first(xml, '//n2:ButtonSource').text
  end
  
  def test_error_code_for_single_error 
    @gateway.expects(:ssl_post).returns(response_with_error)
    response = @gateway.setup_authorization(100, 
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )
    assert_equal "10736", response.params['error_codes']
  end
  
  def test_ensure_only_unique_error_codes
    @gateway.expects(:ssl_post).returns(response_with_duplicate_errors)
    response = @gateway.setup_authorization(100, 
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )
               
    assert_equal "10736" , response.params['error_codes']
  end
  
  def test_error_codes_for_multiple_errors 
    @gateway.expects(:ssl_post).returns(response_with_errors)
    response = @gateway.setup_authorization(100, 
                 :return_url => 'http://example.com',
                 :cancel_return_url => 'http://example.com'
               )
               
    assert_equal ["10736", "10002"] , response.params['error_codes'].split(',')
  end
  
  def test_allow_guest_checkout
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 10, {:allow_guest_checkout => true}))
    
    assert_equal 'Sole', REXML::XPath.first(xml, '//n2:SolutionType').text
    assert_equal 'Billing', REXML::XPath.first(xml, '//n2:LandingPage').text
  end

  private
  def successful_details_response
    <<-RESPONSE
<?xml version='1.0' encoding='UTF-8'?>
<SOAP-ENV:Envelope xmlns:cc='urn:ebay:apis:CoreComponentTypes' xmlns:sizeship='urn:ebay:api:PayPalAPI/sizeship.xsd' xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/' xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:wsu='http://schemas.xmlsoap.org/ws/2002/07/utility' xmlns:ebl='urn:ebay:apis:eBLBaseComponents' xmlns:ds='http://www.w3.org/2000/09/xmldsig#' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:ns='urn:ebay:api:PayPalAPI' xmlns:market='urn:ebay:apis:Market' xmlns:ship='urn:ebay:apis:ship' xmlns:auction='urn:ebay:apis:Auction' xmlns:wsse='http://schemas.xmlsoap.org/ws/2002/12/secext' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>
  <SOAP-ENV:Header>
    <Security xsi:type='wsse:SecurityType' xmlns='http://schemas.xmlsoap.org/ws/2002/12/secext'/>
    <RequesterCredentials xsi:type='ebl:CustomSecurityHeaderType' xmlns='urn:ebay:api:PayPalAPI'>
      <Credentials xsi:type='ebl:UserIdPasswordType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Username xsi:type='xs:string'/>
        <Password xsi:type='xs:string'/>
        <Subject xsi:type='xs:string'/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id='_0'>
    <GetExpressCheckoutDetailsResponse xmlns='urn:ebay:api:PayPalAPI'>
      <Timestamp xmlns='urn:ebay:apis:eBLBaseComponents'>2007-02-12T23:59:43Z</Timestamp>
      <Ack xmlns='urn:ebay:apis:eBLBaseComponents'>Success</Ack>
      <CorrelationID xmlns='urn:ebay:apis:eBLBaseComponents'>c73044f11da65</CorrelationID>
      <Version xmlns='urn:ebay:apis:eBLBaseComponents'>2.000000</Version>
      <Build xmlns='urn:ebay:apis:eBLBaseComponents'>1.0006</Build>
      <GetExpressCheckoutDetailsResponseDetails xsi:type='ebl:GetExpressCheckoutDetailsResponseDetailsType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Token xsi:type='ebl:ExpressCheckoutTokenType'>EC-6WS104951Y388951L</Token>
        <PayerInfo xsi:type='ebl:PayerInfoType'>
          <Payer xsi:type='ebl:EmailAddressType'>buyer@jadedpallet.com</Payer>
          <PayerID xsi:type='ebl:UserIDType'>FWRVKNRRZ3WUC</PayerID>
          <PayerStatus xsi:type='ebl:PayPalUserStatusCodeType'>verified</PayerStatus>
          <PayerName xsi:type='ebl:PersonNameType'>
            <Salutation xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <FirstName xmlns='urn:ebay:apis:eBLBaseComponents'>Fred</FirstName>
            <MiddleName xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <LastName xmlns='urn:ebay:apis:eBLBaseComponents'>Brooks</LastName>
            <Suffix xmlns='urn:ebay:apis:eBLBaseComponents'/>
          </PayerName>
          <PayerCountry xsi:type='ebl:CountryCodeType'>US</PayerCountry>
          <PayerBusiness xsi:type='xs:string'/>
          <Address xsi:type='ebl:AddressType'>
            <Name xsi:type='xs:string'>Fred Brooks</Name>
            <Street1 xsi:type='xs:string'>1234 Penny Lane</Street1>
            <Street2 xsi:type='xs:string'/>
            <CityName xsi:type='xs:string'>Jonsetown</CityName>
            <StateOrProvince xsi:type='xs:string'>NC</StateOrProvince>
            <Country xsi:type='ebl:CountryCodeType'>US</Country>
            <CountryName>United States</CountryName>
            <PostalCode xsi:type='xs:string'>23456</PostalCode>
            <AddressOwner xsi:type='ebl:AddressOwnerCodeType'>PayPal</AddressOwner>
            <AddressStatus xsi:type='ebl:AddressStatusCodeType'>Confirmed</AddressStatus>
          </Address>
        </PayerInfo>
        <InvoiceID xsi:type='xs:string'>1230123</InvoiceID>
      </GetExpressCheckoutDetailsResponseDetails>
    </GetExpressCheckoutDetailsResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>    
    RESPONSE
  end
  
  def successful_transaction_details_response
    <<-RESPONSE
<?xml version='1.0' encoding='UTF-8'?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/' xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:cc='urn:ebay:apis:CoreComponentTypes' xmlns:wsu='http://schemas.xmlsoap.org/ws/2002/07/utility' xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion' xmlns:ds='http://www.w3.org/2000/09/xmldsig#' xmlns:wsse='http://schemas.xmlsoap.org/ws/2002/12/secext' xmlns:ed='urn:ebay:apis:EnhancedDataTypes' xmlns:ebl='urn:ebay:apis:eBLBaseComponents' xmlns:ns='urn:ebay:api:PayPalAPI'>
  <SOAP-ENV:Header>
    <Security xmlns='http://schemas.xmlsoap.org/ws/2002/12/secext' xsi:type='wsse:SecurityType'></Security>
    <RequesterCredentials xmlns='urn:ebay:api:PayPalAPI' xsi:type='ebl:CustomSecurityHeaderType'>
      <Credentials xmlns='urn:ebay:apis:eBLBaseComponents' xsi:type='ebl:UserIdPasswordType'>
        <Username xsi:type='xs:string'></Username>
        <Password xsi:type='xs:string'></Password>
        <Signature xsi:type='xs:string'></Signature>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id='_0'>
    <GetTransactionDetailsResponse xmlns='urn:ebay:api:PayPalAPI'>
      <Timestamp xmlns='urn:ebay:apis:eBLBaseComponents'>2010-12-14T00:17:32Z</Timestamp>
      <Ack xmlns='urn:ebay:apis:eBLBaseComponents'>Success</Ack>
      <CorrelationID xmlns='urn:ebay:apis:eBLBaseComponents'>876620b655650</CorrelationID>
      <Version xmlns='urn:ebay:apis:eBLBaseComponents'>59.0</Version>
      <Build xmlns='urn:ebay:apis:eBLBaseComponents'>1603674</Build>
      <PaymentTransactionDetails xmlns='urn:ebay:apis:eBLBaseComponents' xsi:type='ebl:PaymentTransactionType'>
        <ReceiverInfo xsi:type='ebl:ReceiverInfoType'>
          <Business xsi:type='ebl:EmailAddressType'></Business>
          <Receiver xsi:type='ebl:EmailAddressType'>test-receiver@snaildeal.com</Receiver>
          <ReceiverID xsi:type='ebl:UserIDType'>QWA6NRSTJC2UJ</ReceiverID>
        </ReceiverInfo>
        <PayerInfo xsi:type='ebl:PayerInfoType'>
          <Payer xsi:type='ebl:EmailAddressType'>test-sender@snaildeal.com</Payer>
          <PayerID xsi:type='ebl:UserIDType'>EGURACDVJPULC</PayerID>
          <PayerStatus xsi:type='ebl:PayPalUserStatusCodeType'>verified</PayerStatus>
          <PayerName xsi:type='ebl:PersonNameType'>
            <Salutation xmlns='urn:ebay:apis:eBLBaseComponents'></Salutation>
            <FirstName xmlns='urn:ebay:apis:eBLBaseComponents'>Test</FirstName>
            <MiddleName xmlns='urn:ebay:apis:eBLBaseComponents'></MiddleName>
            <LastName xmlns='urn:ebay:apis:eBLBaseComponents'>User</LastName>
            <Suffix xmlns='urn:ebay:apis:eBLBaseComponents'></Suffix>
          </PayerName>
          <PayerCountry xsi:type='ebl:CountryCodeType'>US</PayerCountry>
          <PayerBusiness xsi:type='xs:string'></PayerBusiness>
          <Address xsi:type='ebl:AddressType'>
            <Name xsi:type='xs:string'>Test User</Name>
            <Street1 xsi:type='xs:string'>1 Main St</Street1>
            <Street2 xsi:type='xs:string'></Street2>
            <CityName xsi:type='xs:string'>San Jose</CityName>
            <StateOrProvince xsi:type='xs:string'>CA</StateOrProvince>
            <Country xsi:type='ebl:CountryCodeType'>US</Country>
            <CountryName>United States</CountryName>
            <PostalCode xsi:type='xs:string'>95131</PostalCode>
            <AddressOwner xsi:type='ebl:AddressOwnerCodeType'>PayPal</AddressOwner>
            <AddressStatus xsi:type='ebl:AddressStatusCodeType'>Confirmed</AddressStatus>
          </Address>
          <ContactPhone xsi:type='xs:string'></ContactPhone>
        </PayerInfo>
        <PaymentInfo xsi:type='ebl:PaymentInfoType'>
          <TransactionID>1GR40996P1767570Y</TransactionID>
          <ParentTransactionID xsi:type='ebl:TransactionId'>9BV74148LS099724N</ParentTransactionID>
          <ReceiptID></ReceiptID>
          <TransactionType xsi:type='ebl:PaymentTransactionCodeType'>express-checkout</TransactionType>
          <PaymentType xsi:type='ebl:PaymentCodeType'>instant</PaymentType>
          <PaymentDate xsi:type='xs:dateTime'>2010-12-01T12:57:02Z</PaymentDate>
          <GrossAmount xsi:type='cc:BasicAmountType' currencyID='USD'>12.59</GrossAmount>
          <FeeAmount xsi:type='cc:BasicAmountType' currencyID='USD'>0.67</FeeAmount>
          <TaxAmount xsi:type='cc:BasicAmountType' currencyID='USD'>0.00</TaxAmount>
          <ExchangeRate xsi:type='xs:string'></ExchangeRate>
          <PaymentStatus xsi:type='ebl:PaymentStatusCodeType'>Refunded</PaymentStatus>
          <PendingReason xsi:type='ebl:PendingStatusCodeType'>none</PendingReason>
          <ReasonCode xsi:type='ebl:ReversalReasonCodeType'>refund</ReasonCode>
          <ProtectionEligibility xsi:type='xs:string'>Eligible</ProtectionEligibility>
          <ShipAmount xsi:type='xs:string'>0.00</ShipAmount>
          <ShipHandleAmount xsi:type='xs:string'>0.00</ShipHandleAmount>
          <ShipDiscount xsi:type='xs:string'></ShipDiscount>
          <InsuranceAmount xsi:type='xs:string'></InsuranceAmount>
          <Subject xsi:type='xs:string'></Subject>
        </PaymentInfo>
        <PaymentItemInfo xsi:type='ebl:PaymentItemInfoType'>
          <InvoiceID xsi:type='xs:string'></InvoiceID>
          <Custom xsi:type='xs:string'></Custom>
          <Memo xsi:type='xs:string'></Memo>
          <SalesTax xsi:type='xs:string'>0.00</SalesTax>
          <PaymentItem xmlns='urn:ebay:apis:eBLBaseComponents' xsi:type='ebl:PaymentItemType'>
            <Name xsi:type='xs:string'></Name>
            <Number xsi:type='xs:string'></Number>
            <Quantity xsi:type='xs:string'>1</Quantity>
            <SalesTax xsi:type='xs:string'>0.00</SalesTax>
            <ShippingAmount xsi:type='xs:string'></ShippingAmount>
            <HandlingAmount xsi:type='xs:string'></HandlingAmount>
          </PaymentItem>
          <Subscription xsi:type='ebl:SubscriptionInfoType' recurring='' reattempt=''>
            <SubscriptionID></SubscriptionID>
            <Username xsi:type='xs:string'></Username>
            <Password xsi:type='xs:string'></Password>
            <Recurrences xsi:type='xs:string'></Recurrences>
          </Subscription>
          <Auction xsi:type='ebl:AuctionInfoType' multiItem=''>
            <BuyerID xsi:type='xs:string'></BuyerID>
          </Auction>
        </PaymentItemInfo>
      </PaymentTransactionDetails>
    </GetTransactionDetailsResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def successful_authorization_response
    <<-RESPONSE
<?xml version='1.0' encoding='UTF-8'?>
<SOAP-ENV:Envelope xmlns:cc='urn:ebay:apis:CoreComponentTypes' xmlns:sizeship='urn:ebay:api:PayPalAPI/sizeship.xsd' xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/' xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:wsu='http://schemas.xmlsoap.org/ws/2002/07/utility' xmlns:ebl='urn:ebay:apis:eBLBaseComponents' xmlns:ds='http://www.w3.org/2000/09/xmldsig#' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:ns='urn:ebay:api:PayPalAPI' xmlns:market='urn:ebay:apis:Market' xmlns:ship='urn:ebay:apis:ship' xmlns:auction='urn:ebay:apis:Auction' xmlns:wsse='http://schemas.xmlsoap.org/ws/2002/12/secext' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>
  <SOAP-ENV:Header>
    <Security xsi:type='wsse:SecurityType' xmlns='http://schemas.xmlsoap.org/ws/2002/12/secext'/>
    <RequesterCredentials xsi:type='ebl:CustomSecurityHeaderType' xmlns='urn:ebay:api:PayPalAPI'>
      <Credentials xsi:type='ebl:UserIdPasswordType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Username xsi:type='xs:string'/>
        <Password xsi:type='xs:string'/>
        <Subject xsi:type='xs:string'/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id='_0'>
    <DoExpressCheckoutPaymentResponse xmlns='urn:ebay:api:PayPalAPI'>
      <Timestamp xmlns='urn:ebay:apis:eBLBaseComponents'>2007-02-13T00:18:50Z</Timestamp>
      <Ack xmlns='urn:ebay:apis:eBLBaseComponents'>Success</Ack>
      <CorrelationID xmlns='urn:ebay:apis:eBLBaseComponents'>62450a4266d04</CorrelationID>
      <Version xmlns='urn:ebay:apis:eBLBaseComponents'>2.000000</Version>
      <Build xmlns='urn:ebay:apis:eBLBaseComponents'>1.0006</Build>
      <DoExpressCheckoutPaymentResponseDetails xsi:type='ebl:DoExpressCheckoutPaymentResponseDetailsType' xmlns='urn:ebay:apis:eBLBaseComponents'>
        <Token xsi:type='ebl:ExpressCheckoutTokenType'>EC-6WS104951Y388951L</Token>
        <PaymentInfo xsi:type='ebl:PaymentInfoType'>
          <TransactionID>8B266858CH956410C</TransactionID>
          <ParentTransactionID xsi:type='ebl:TransactionId'/>
          <ReceiptID/>
          <TransactionType xsi:type='ebl:PaymentTransactionCodeType'>express-checkout</TransactionType>
          <PaymentType xsi:type='ebl:PaymentCodeType'>instant</PaymentType>
          <PaymentDate xsi:type='xs:dateTime'>2007-02-13T00:18:48Z</PaymentDate>
          <GrossAmount currencyID='USD' xsi:type='cc:BasicAmountType'>3.00</GrossAmount>
          <TaxAmount currencyID='USD' xsi:type='cc:BasicAmountType'>0.00</TaxAmount>
          <ExchangeRate xsi:type='xs:string'/>
          <PaymentStatus xsi:type='ebl:PaymentStatusCodeType'>Pending</PaymentStatus>
          <PendingReason xsi:type='ebl:PendingStatusCodeType'>authorization</PendingReason>
          <ReasonCode xsi:type='ebl:ReversalReasonCodeType'>none</ReasonCode>
        </PaymentInfo>
      </DoExpressCheckoutPaymentResponseDetails>
    </DoExpressCheckoutPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def response_with_error
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"/>
        <Password xsi:type="xs:string"/>
        <Subject xsi:type="xs:string"/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
      <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
        <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
        <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
        <ErrorCode xsi:type="xs:token">10736</ErrorCode>
        <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
      </Errors>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
    </SetExpressCheckoutResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
    def response_with_errors
      <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
    <SOAP-ENV:Header>
      <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
      <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
        <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
          <Username xsi:type="xs:string"/>
          <Password xsi:type="xs:string"/>
          <Subject xsi:type="xs:string"/>
        </Credentials>
      </RequesterCredentials>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body id="_0">
      <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
        <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
        <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
        <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
          <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
          <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
          <ErrorCode xsi:type="xs:token">10736</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
           <ShortMessage xsi:type="xs:string">Authentication/Authorization Failed</ShortMessage>
          <LongMessage xsi:type="xs:string">You do not have permissions to make this API call</LongMessage>
          <ErrorCode xsi:type="xs:token">10002</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
        <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
      </SetExpressCheckoutResponse>
    </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
      RESPONSE
    end
    
      def response_with_duplicate_errors
      <<-RESPONSE
  <?xml version="1.0" encoding="UTF-8"?>
  <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:market="urn:ebay:apis:Market" xmlns:auction="urn:ebay:apis:Auction" xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" xmlns:ship="urn:ebay:apis:ship" xmlns:skype="urn:ebay:apis:skype" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
    <SOAP-ENV:Header>
      <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
      <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
        <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
          <Username xsi:type="xs:string"/>
          <Password xsi:type="xs:string"/>
          <Subject xsi:type="xs:string"/>
        </Credentials>
      </RequesterCredentials>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body id="_0">
      <SetExpressCheckoutResponse xmlns="urn:ebay:api:PayPalAPI">
        <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-04-02T17:38:02Z</Timestamp>
        <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
        <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">cdb720feada30</CorrelationID>
        <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
          <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
          <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
          <ErrorCode xsi:type="xs:token">10736</ErrorCode>
          <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
         <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
            <ShortMessage xsi:type="xs:string">Shipping Address Invalid City State Postal Code</ShortMessage>
            <LongMessage xsi:type="xs:string">A match of the Shipping Address City, State, and Postal Code failed.</LongMessage>
            <ErrorCode xsi:type="xs:token">10736</ErrorCode>
            <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
        </Errors>
        <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
        <Build xmlns="urn:ebay:apis:eBLBaseComponents">543066</Build>
      </SetExpressCheckoutResponse>
    </SOAP-ENV:Body>
  </SOAP-ENV:Envelope>
      RESPONSE
    end  
end
