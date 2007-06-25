require File.dirname(__FILE__) + '/../../test_helper'

class PaypalTest < Test::Unit::TestCase
  def setup
    @gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :pem => ''
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

    @creditcard = credit_card('4242424242424242')
    
    Base.gateway_mode = :test
  end 
  
  def teardown
    Base.gateway_mode = :test
    PaypalGateway.pem_file = nil
  end 

  def test_no_ip_address
    assert_raise(ArgumentError){ @gateway.purchase(100, @creditcard, :address => @address)}
  end

  def test_purchase_success    
    @creditcard.number = 1

    assert response = @gateway.purchase(100, @creditcard, :address => @address, :ip => '127.0.0.1')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal true, response.success?
  end

  def test_purchase_error
    @creditcard.number = 2

    assert response = @gateway.purchase(100, @creditcard, :order_id => 1, :address => @address, :ip => '127.0.0.1')
    assert_equal Response, response.class
    assert_equal '#0001', response.params['receiptid']
    assert_equal false, response.success?

  end
  
  def test_reauthorization
    @gateway.expects(:ssl_post).returns(successful_reauthorization_response)
    response = @gateway.reauthorize(1000, '32J876265E528623B')
    assert response.success?
    assert_equal('1TX27389GX108740X', response.authorization)
    assert response.test?
  end
  
  def test_purchase_exceptions
    @creditcard.number = 3 
    
    assert_raise(Error) do
      assert response = @gateway.purchase(100, @creditcard, :order_id => 1, :address => @address, :ip => '127.0.0.1')   
    end
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_paypal_timeout_error
    @gateway.stubs(:ssl_post).returns(paypal_timeout_error_response)
    response = @gateway.purchase(100, @creditcard, :order_id => 1, :address => @address, :ip => '127.0.0.1')
    assert_equal "SOAP-ENV:Server", response.params['faultcode']
    assert_equal "Internal error", response.params['faultstring']
    assert_equal "Timeout processing request", response.params['detail']
    assert_equal "SOAP-ENV:Server: Internal error - Timeout processing request", response.message
  end
  
  def test_pem_file_accessor
    PaypalGateway.pem_file = '123456'
    gateway = PaypalGateway.new(:login => 'test', :password => 'test')
    assert_equal '123456', gateway.options[:pem]
  end
  
  def test_passed_in_pem_overrides_class_accessor
    PaypalGateway.pem_file = '123456'
    gateway = PaypalGateway.new(:login => 'test', :password => 'test', :pem => 'Clobber')
    assert_equal 'Clobber', gateway.options[:pem]
  end
  
  def test_ensure_options_are_transferred_to_express_instance
    PaypalGateway.pem_file = '123456'
    gateway = PaypalGateway.new(:login => 'test', :password => 'password')
    express = gateway.express
    assert_instance_of PaypalExpressGateway, express
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
    assert_equal '123456', express.options[:pem]
  end
  
  def test_successful_state_lookup
    assert_equal 'AB', @gateway.send(:lookup_state, { :country => 'CA', :state => 'AB'})
  end
  
  def test_lookup_unknown_state
    assert_equal '', @gateway.send(:lookup_state, { :country => 'XX', :state => 'NA'})
  end
  
  def test_lookup_uk_with_state
    assert_equal 'Avon', @gateway.send(:lookup_state, { :country => 'United Kingdom', :state => 'Avon'})
  end
  
  def test_lookup_uk_with_no_state
    assert_equal 'N/A', @gateway.send(:lookup_state, { :country => 'GB', :state => '' })
  end
  
  def test_lookup_australian_state
    assert_equal 'Australian Capital Territory', @gateway.send(:lookup_state, { :country => 'AU', :state => 'ACT'} )
  end
  
  def test_supported_countries
    assert_equal ['US'], PaypalGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], PaypalGateway.supported_cardtypes
  end
  
  def test_button_source
    PaypalGateway.application_id = 'ActiveMerchant_DC'
    
    xml = REXML::Document.new(@gateway.send(:build_sale_or_authorization_request, 'Test', 100, @creditcard, {}))
    assert_equal 'ActiveMerchant_DC', REXML::XPath.first(xml, '//n2:ButtonSource').text
  end
  
  def test_item_total_shipping_handling_and_tax_not_included_unless_all_are_present
    xml = @gateway.send(:build_sale_or_authorization_request, 'Authorization', 100, @creditcard,
      :tax => 100,
      :shipping => 100,
      :handling => 100
    )
    
    doc = REXML::Document.new(xml)
    assert_nil REXML::XPath.first(doc, '//n2:PaymentDetails/n2:TaxTotal')
  end
  
  def test_item_total_shipping_handling_and_tax
    xml = @gateway.send(:build_sale_or_authorization_request, 'Authorization', 100, @creditcard,
      :tax => 100,
      :shipping => 100,
      :handling => 100,
      :subtotal => 200
    )
    
    doc = REXML::Document.new(xml)
    assert_equal '1.00', REXML::XPath.first(doc, '//n2:PaymentDetails/n2:TaxTotal').text
  end
  
  private
  def paypal_timeout_error_response
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
    <SOAP-ENV:Fault>
      <faultcode>SOAP-ENV:Server</faultcode>
      <faultstring>Internal error</faultstring>
      <detail>Timeout processing request</detail>
    </SOAP-ENV:Fault>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def successful_reauthorization_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope 
  xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" 
  xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema" 
  xmlns:cc="urn:ebay:apis:CoreComponentTypes" 
  xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" 
  xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" 
  xmlns:ds="http://www.w3.org/2000/09/xmldsig#" 
  xmlns:market="urn:ebay:apis:Market" 
  xmlns:auction="urn:ebay:apis:Auction" 
  xmlns:sizeship="urn:ebay:api:PayPalAPI/sizeship.xsd" 
  xmlns:ship="urn:ebay:apis:ship" 
  xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" 
  xmlns:ebl="urn:ebay:apis:eBLBaseComponents" 
  xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security 
       xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" 
       xsi:type="wsse:SecurityType">
    </Security>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" 
       xsi:type="ebl:CustomSecurityHeaderType">
       <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" 
                    xsi:type="ebl:UserIdPasswordType">
          <Username xsi:type="xs:string"></Username>
          <Password xsi:type="xs:string"></Password>
          <Subject xsi:type="xs:string"></Subject>
       </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <DoReauthorizationResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2007-03-04T23:34:42Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">e444ddb7b3ed9</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1.0006</Build>
      <AuthorizationID xsi:type="ebl:AuthorizationId">1TX27389GX108740X</AuthorizationID>
    </DoReauthorizationResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>  
    RESPONSE
  end
end
