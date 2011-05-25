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
    
    assert_equal 'EC-2XE90996XX9870316', response.token
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
    assert_equal '416-618-9984', address['phone']
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

  def test_includes_description
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :description => 'a description' }))

    assert_equal 'a description', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:OrderDescription').text
  end

  def test_includes_order_id
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :order_id => '12345' }))

    assert_equal '12345', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:InvoiceID').text
  end

  def test_includes_correct_payment_action
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { }))

    assert_equal 'SetExpressCheckout', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentAction').text
  end
  
  def test_does_not_include_items_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))

    assert_nil REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem')
  end

  def test_items_are_included_if_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {:currency => 'GBP', :items => [
                                            {:name => 'item one', :description => 'item one description', :amount => 10000, :number => 1, :quantity => 3},
                                            {:name => 'item two', :description => 'item two description', :amount => 20000, :number => 2, :quantity => 4}
    ]}))

    assert_equal 'item one', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name').text
    assert_equal 'item one description', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description').text
    assert_equal '100.00', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount').text
    assert_equal 'GBP', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount').attribute('currencyID').value
    assert_equal '1', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number').text
    assert_equal '3', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity').text

    assert_equal 'item two', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Name')[1].text
    assert_equal 'item two description', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Description')[1].text
    assert_equal '200.00', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount')[1].text
    assert_equal 'GBP', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Amount')[1].attribute('currencyID').value
    assert_equal '2', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Number')[1].text
    assert_equal '4', REXML::XPath.match(xml, '//n2:PaymentDetails/n2:PaymentDetailsItem/n2:Quantity')[1].text
  end

  def test_handle_non_zero_amount
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 50, {}))
    
    assert_equal '0.50', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:OrderTotal').text
  end
  
  def test_handles_zero_amount
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, {}))
    
    assert_equal '1.00', REXML::XPath.first(xml, '//n2:PaymentDetails/n2:OrderTotal').text
  end
  
  def test_amount_format_for_jpy_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/n2:OrderTotal currencyID=.JPY.>1<\/n2:OrderTotal>/)).returns(successful_authorization_response)
    response = @gateway.authorize(100, :token => 'EC-6WS104951Y388951L', :payer_id => 'FWRVKNRRZ3WUC', :currency => 'JPY')
    assert response.success?
  end

  def test_does_not_add_allow_note_if_not_specified
    xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { }))

    assert_nil REXML::XPath.first(xml, '//n2:AllowNote')
  end

  def test_adds_allow_note_if_specified
    allow_notes_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :allow_note => true }))
    do_not_allow_notes_xml = REXML::Document.new(@gateway.send(:build_setup_request, 'SetExpressCheckout', 0, { :allow_note => false }))

    assert_equal '1', REXML::XPath.first(allow_notes_xml, '//n2:AllowNote').text
    assert_equal '0', REXML::XPath.first(do_not_allow_notes_xml, '//n2:AllowNote').text
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
  
  def test_get_phone_number_from_address_if_contact_phone_not_sent
    response = successful_details_response.sub(%r{<ContactPhone>416-618-9984</ContactPhone>\n}, '')
    @gateway.expects(:ssl_post).returns(response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
    assert address = response.address
    assert_equal '123-456-7890', address['phone']
  end
  
  private
  def successful_details_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ed="urn:ebay:apis:EnhancedDataTypes" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
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
    <GetExpressCheckoutDetailsResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2011-03-01T20:19:35Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">84aff0e17b6f</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">62.0</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1741654</Build>
      <GetExpressCheckoutDetailsResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:GetExpressCheckoutDetailsResponseDetailsType">
        <Token xsi:type="ebl:ExpressCheckoutTokenType">EC-2XE90996XX9870316</Token>
        <PayerInfo xsi:type="ebl:PayerInfoType">
          <Payer xsi:type="ebl:EmailAddressType">buyer@jadedpallet.com</Payer>
          <PayerID xsi:type="ebl:UserIDType">FWRVKNRRZ3WUC</PayerID>
          <PayerStatus xsi:type="ebl:PayPalUserStatusCodeType">verified</PayerStatus>
          <PayerName xsi:type='ebl:PersonNameType'>
            <Salutation xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <FirstName xmlns='urn:ebay:apis:eBLBaseComponents'>Fred</FirstName>
            <MiddleName xmlns='urn:ebay:apis:eBLBaseComponents'/>
            <LastName xmlns='urn:ebay:apis:eBLBaseComponents'>Brooks</LastName>
            <Suffix xmlns='urn:ebay:apis:eBLBaseComponents'/>
          </PayerName>
          <PayerCountry xsi:type="ebl:CountryCodeType">US</PayerCountry>
          <PayerBusiness xsi:type="xs:string"/>
          <Address xsi:type="ebl:AddressType">
            <Name xsi:type="xs:string">Fred Brooks</Name>
            <Street1 xsi:type="xs:string">1 Infinite Loop</Street1>
            <Street2 xsi:type="xs:string"/>
            <CityName xsi:type="xs:string">Cupertino</CityName>
            <StateOrProvince xsi:type="xs:string">CA</StateOrProvince>
            <Country xsi:type="ebl:CountryCodeType">US</Country>
            <CountryName>United States</CountryName>
            <PostalCode xsi:type="xs:string">95014</PostalCode>
            <AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
            <AddressStatus xsi:type="ebl:AddressStatusCodeType">Confirmed</AddressStatus>
          </Address>
        </PayerInfo>
        <InvoiceID xsi:type="xs:string">1230123</InvoiceID>
        <ContactPhone>416-618-9984</ContactPhone>
        <PaymentDetails xsi:type="ebl:PaymentDetailsType">
          <OrderTotal xsi:type="cc:BasicAmountType" currencyID="USD">19.00</OrderTotal>
          <ItemTotal xsi:type="cc:BasicAmountType" currencyID="USD">19.00</ItemTotal>
          <ShippingTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</ShippingTotal>
          <HandlingTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</HandlingTotal>
          <TaxTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</TaxTotal>
          <ShipToAddress xsi:type="ebl:AddressType">
            <Name xsi:type="xs:string">Fred Brooks</Name>
            <Street1 xsi:type="xs:string">1234 Penny Lane</Street1>
            <Street2 xsi:type="xs:string"/>
            <CityName xsi:type="xs:string">Jonsetown</CityName>
            <StateOrProvince xsi:type="xs:string">NC</StateOrProvince>
            <Country xsi:type="ebl:CountryCodeType">US</Country>
            <CountryName>United States</CountryName>
            <Phone xsi:type="xs:string">123-456-7890</Phone>
            <PostalCode xsi:type="xs:string">23456</PostalCode>
            <AddressID xsi:type="xs:string"/>
            <AddressOwner xsi:type="ebl:AddressOwnerCodeType">PayPal</AddressOwner>
            <ExternalAddressID xsi:type="xs:string"/>
            <AddressStatus xsi:type="ebl:AddressStatusCodeType">Confirmed</AddressStatus>
          </ShipToAddress>
          <PaymentDetailsItem xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:PaymentDetailsItemType">
            <Name xsi:type="xs:string">Shopify T-Shirt</Name>
            <Quantity>1</Quantity>
            <Tax xsi:type="cc:BasicAmountType" currencyID="USD">0.00</Tax>
            <Amount xsi:type="cc:BasicAmountType" currencyID="USD">19.00</Amount>
            <EbayItemPaymentDetailsItem xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:EbayItemPaymentDetailsItemType"/>
          </PaymentDetailsItem>
          <InsuranceTotal xsi:type="cc:BasicAmountType" currencyID="USD">0.00</InsuranceTotal>
          <ShippingDiscount xsi:type="cc:BasicAmountType" currencyID="USD">0.00</ShippingDiscount>
          <InsuranceOptionOffered xsi:type="xs:string">false</InsuranceOptionOffered>
          <SellerDetails xsi:type="ebl:SellerDetailsType"/>
          <PaymentRequestID xsi:type="xs:string"/>
          <OrderURL xsi:type="xs:string"/>
          <SoftDescriptor xsi:type="xs:string"/>
        </PaymentDetails>
        <CheckoutStatus xsi:type="xs:string">PaymentActionNotInitiated</CheckoutStatus>
      </GetExpressCheckoutDetailsResponseDetails>
    </GetExpressCheckoutDetailsResponse>
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
