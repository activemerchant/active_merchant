require 'test_helper'

class PaypalTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    PaypalGateway.pem_file = nil
    
    @amount = 100
    @gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :pem => 'PEM'
               )
    
    @credit_card = credit_card('4242424242424242')
    @options = { :billing_address => address, :ip => '127.0.0.1' }
    @recurring_required_fields = {:start_date => Date.today, :frequency => :Month, :period => 'Month', :description => 'A description'}
  end 

  def test_no_ip_address
    assert_raise(ArgumentError){ @gateway.purchase(@amount, @credit_card, :billing_address => address)}
  end

  def test_recurring_requires_description
    @recurring_required_fields.delete(:description)
    assert_raise(ArgumentError){ @gateway.recurring(@amount, @credit_card, @options.merge(@recurring_required_fields)) }
  end

  def test_recurring_requires_start_date
    @recurring_required_fields.delete(:start_date)
    assert_raise(ArgumentError){ @gateway.recurring(@amount, @credit_card, @options.merge(@recurring_required_fields)) }
  end

  def test_recurring_requires_frequency
    @recurring_required_fields.delete(:frequency)
    assert_raise(ArgumentError){ @gateway.recurring(@amount, @credit_card, @options.merge(@recurring_required_fields)) }
  end

  def test_recurring_requires_period
    @recurring_required_fields.delete(:period)
    assert_raise(ArgumentError){ @gateway.recurring(@amount, @credit_card, @options.merge(@recurring_required_fields)) }
  end

  def test_update_recurring_requires_profile_id
    assert_raise(ArgumentError){ @gateway.update_recurring(:amount => 100)}
  end

  def test_cancel_recurring_requires_profile_id
    assert_raise(ArgumentError){ @gateway.cancel_recurring(nil, :note => 'Note')}
  end

  def test_status_recurring_requires_profile_id
    assert_raise(ArgumentError){ @gateway.status_recurring(nil, :note => 'Note')}
  end

  def test_suspend_recurring_requires_profile_id
    assert_raise(ArgumentError){ @gateway.suspend_recurring(nil, :note => 'Note')}
  end

  def test_reactivate_recurring_requires_profile_id
    assert_raise(ArgumentError){ @gateway.reactivate_recurring(nil, :note => 'Note')}
  end

  def test_successful_purchase_with_auth_signature
    @gateway = PaypalGateway.new(:login => 'cody', :password => 'test', :pem => 'PEM', :auth_signature => 123)
    expected_header = {'X-PP-AUTHORIZATION' => 123, 'X-PAYPAL-MESSAGE-PROTOCOL' => 'SOAP11'}
    @gateway.expects(:ssl_post).with(anything, anything, expected_header).returns(successful_purchase_response)
    @gateway.expects(:add_credentials).never
 
    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase_without_auth_signature
    @gateway = PaypalGateway.new(:login => 'cody', :password => 'test', :pem => 'PEM')
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:add_credentials)

    assert @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '62U664727W5914806', response.authorization
    assert response.test?
  end
  
  def test_successful_reference_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '62U664727W5914806', response.authorization
    
    ref_id = response.authorization
    
    gateway2 = PaypalGateway.new(:login => 'cody', :password => 'test', :pem => 'PEM')
    gateway2.expects(:ssl_post).returns(successful_reference_purchase_response)
    assert response = gateway2.purchase(@amount, ref_id, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '62U664727W5915049', response.authorization
    assert response.test?
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_reauthorization
    @gateway.expects(:ssl_post).returns(successful_reauthorization_response)
    response = @gateway.reauthorize(@amount, '32J876265E528623B')
    assert response.success?
    assert_equal('1TX27389GX108740X', response.authorization)
    assert response.test?
  end
  
  def test_reauthorization_with_warning
    @gateway.expects(:ssl_post).returns(successful_with_warning_reauthorization_response)
    response = @gateway.reauthorize(@amount, '32J876265E528623B')
    assert response.success?
    assert_equal('1TX27389GX108740X', response.authorization)
    assert response.test?
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_paypal_timeout_error
    @gateway.stubs(:ssl_post).returns(paypal_timeout_error_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
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
  
  def test_supported_countries
    assert_equal ['US'], PaypalGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], PaypalGateway.supported_cardtypes
  end
  
  def test_button_source
    PaypalGateway.application_id = 'ActiveMerchant_DC'
    
    xml = REXML::Document.new(@gateway.send(:build_sale_or_authorization_request, 'Test', @amount, @credit_card, {}))
    assert_equal 'ActiveMerchant_DC', REXML::XPath.first(xml, '//n2:ButtonSource').text
  end
  
  def test_item_total_shipping_handling_and_tax_not_included_unless_all_are_present
    xml = @gateway.send(:build_sale_or_authorization_request, 'Authorization', @amount, @credit_card,
      :tax => @amount,
      :shipping => @amount,
      :handling => @amount
    )
    
    doc = REXML::Document.new(xml)
    assert_nil REXML::XPath.first(doc, '//n2:PaymentDetails/n2:TaxTotal')
  end
  
  def test_item_total_shipping_handling_and_tax
    xml = @gateway.send(:build_sale_or_authorization_request, 'Authorization', @amount, @credit_card,
      :tax => @amount,
      :shipping => @amount,
      :handling => @amount,
      :subtotal => 200
    )
    
    doc = REXML::Document.new(xml)
    assert_equal '1.00', REXML::XPath.first(doc, '//n2:PaymentDetails/n2:TaxTotal').text
  end
  
  def test_should_use_test_certificate_endpoint
    gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :pem => 'PEM'
              )
    assert_equal PaypalGateway::URLS[:test][:certificate], gateway.send(:endpoint_url)
  end
  
  def test_should_use_live_certificate_endpoint
    gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :pem => 'PEM'
              )
    gateway.expects(:test?).returns(false)
      
    assert_equal PaypalGateway::URLS[:live][:certificate], gateway.send(:endpoint_url)
  end
  
  def test_should_use_test_signature_endpoint
    gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :signature => 'SIG'
              )
      
    assert_equal PaypalGateway::URLS[:test][:signature], gateway.send(:endpoint_url)
  end
  
  def test_should_use_live_signature_endpoint
    gateway = PaypalGateway.new(
                :login => 'cody', 
                :password => 'test',
                :signature => 'SIG'
              )
    gateway.expects(:test?).returns(false)
      
    assert_equal PaypalGateway::URLS[:live][:signature], gateway.send(:endpoint_url)
  end
  
  def test_should_raise_argument_when_credentials_not_present
    assert_raises(ArgumentError) do
      PaypalGateway.new(:login => 'cody', :password => 'test')
    end
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end
     
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_fraud_review
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "SuccessWithWarning", response.params["ack"]
    assert_equal "Payment Pending your review in Fraud Management Filters", response.message
    assert response.fraud_review?
  end
  
  def test_failed_capture_due_to_pending_fraud_review
    @gateway.expects(:ssl_post).returns(failed_capture_due_to_pending_fraud_review)
    
    response = @gateway.capture(@amount, 'authorization')
    assert_failure response
    assert_equal "Transaction must be accepted in Fraud Management Filters before capture.", response.message
  end
  
  # This occurs when sufficient 3rd party API permissions are not present to make the call for the user
  def test_authentication_failed_response
    @gateway.expects(:ssl_post).returns(authentication_failed_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "10002", response.params["error_codes"]
    assert_equal "You do not have permissions to make this API call", response.message
  end
  
  def test_amount_format_for_jpy_currency
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/n2:OrderTotal currencyID=.JPY.>1<\/n2:OrderTotal>/), {}).returns(successful_purchase_response)
    response = @gateway.purchase(100, @credit_card, @options.merge(:currency => 'JPY'))
    assert response.success?
  end

  def test_successful_create_profile
    @gateway.expects(:ssl_post).returns(successful_create_profile_paypal_response)
    response = @gateway.recurring(@amount, @credit_card, :description => "some description", :start_date => Time.now, :frequency => 12, :period => 'Month')
    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal 'I-G7A2FF8V75JY', response.params['profile_id']
    assert_equal 'ActiveProfile', response.params['profile_status']
  end

  def test_failed_create_profile
    @gateway.expects(:ssl_post).returns(failed_create_profile_paypal_response)
    response = @gateway.recurring(@amount, @credit_card, :description => "some description", :start_date => Time.now, :frequency => 12, :period => 'Month')
    assert_instance_of Response, response
    assert !response.success?
    assert response.test?
    assert_equal 'I-G7A2FF8V75JY', response.params['profile_id']
    assert_equal 'ActiveProfile', response.params['profile_status']
  end

  def test_update_recurring_delegation
    @gateway.expects(:build_change_profile_request).with('I-G7A2FF8V75JY', :amount => 200)
    @gateway.stubs(:commit)
    @gateway.update_recurring(:profile_id => 'I-G7A2FF8V75JY', :amount => 200)
  end

  def test_update_recurring_response
    @gateway.expects(:ssl_post).returns(successful_update_recurring_payment_profile_response)
    response = @gateway.update_recurring(:profile_id => 'I-G7A2FF8V75JY', :amount => 200)
    assert response.success?
  end

  def test_cancel_recurring_delegation
    @gateway.expects(:build_manage_profile_request).with('I-G7A2FF8V75JY', 'Cancel', :note => 'A Note').returns(:cancel_request)
    @gateway.expects(:commit).with('ManageRecurringPaymentsProfileStatus', :cancel_request)
    @gateway.cancel_recurring('I-G7A2FF8V75JY', :note => 'A Note')
  end

  def test_suspend_recurring_delegation
    @gateway.expects(:build_manage_profile_request).with('I-G7A2FF8V75JY', 'Suspend', :note => 'A Note').returns(:request)
    @gateway.expects(:commit).with('ManageRecurringPaymentsProfileStatus', :request)
    @gateway.suspend_recurring('I-G7A2FF8V75JY', :note => 'A Note')
  end

  def test_reactivate_recurring_delegation
    @gateway.expects(:build_manage_profile_request).with('I-G7A2FF8V75JY', 'Reactivate', :note => 'A Note').returns(:request)
    @gateway.expects(:commit).with('ManageRecurringPaymentsProfileStatus', :request)
    @gateway.reactivate_recurring('I-G7A2FF8V75JY', :note => 'A Note')
  end

  def test_status_recurring_delegation
    @gateway.expects(:build_get_profile_details_request).with('I-G7A2FF8V75JY').returns(:request)
    @gateway.expects(:commit).with('GetRecurringPaymentsProfileDetails', :request)
    @gateway.status_recurring('I-G7A2FF8V75JY')
  end

  def test_status_recurring_response
    @gateway.expects(:ssl_post).returns(succesful_get_recurring_payments_profile_response)
    response = @gateway.status_recurring('I-M1L3RX91DPDD')
    assert response.success?
    assert_equal 'I-M1L3RX91DPDD', response.params['profile_id']
  end

  def test_bill_outstanding_amoung_delegation
    @gateway.expects(:build_bill_outstanding_amount).with('I-G7A2FF8V75JY', :amount => 400).returns(:request)
    @gateway.expects(:commit).with('BillOutstandingAmount', :request)
    @gateway.bill_outstanding_amount('I-G7A2FF8V75JY', :amount => 400)
  end

  def test_bill_outstanding_amoung_response
    @gateway.expects(:ssl_post).returns(successful_bill_outstanding_amount)
    response = @gateway.bill_outstanding_amount('I-G7A2FF8V75JY', :amount => 400)
    assert response.success?
  end




  private
  def successful_purchase_response
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
    <DoDirectPaymentResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-01-06T23:41:25Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">fee61882e6f47</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1.0006</Build>
      <Amount xsi:type="cc:BasicAmountType" currencyID="USD">3.00</Amount>
      <AVSCode xsi:type="xs:string">X</AVSCode>
      <CVV2Code xsi:type="xs:string">M</CVV2Code>
      <TransactionID>62U664727W5914806</TransactionID>
    </DoDirectPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def successful_reference_purchase_response
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
    <DoReferenceTransactionResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-01-06T23:41:25Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Success</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">fee61882e6f47</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1.0006</Build>
      <Amount xsi:type="cc:BasicAmountType" currencyID="USD">3.00</Amount>
      <AVSCode xsi:type="xs:string">X</AVSCode>
      <CVV2Code xsi:type="xs:string">M</CVV2Code>
      <TransactionID>62U664727W5915049</TransactionID>
    </DoReferenceTransactionResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def failed_purchase_response
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
    <DoDirectPaymentResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-01-06T23:41:25Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">fee61882e6f47</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1.0006</Build>
      <Amount xsi:type="cc:BasicAmountType" currencyID="USD">3.00</Amount>
      <AVSCode xsi:type="xs:string">X</AVSCode>
      <CVV2Code xsi:type="xs:string">M</CVV2Code>
    </DoDirectPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
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
  
  def successful_with_warning_reauthorization_response
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
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">SuccessWithWarning</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">e444ddb7b3ed9</CorrelationID>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">2.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">1.0006</Build>
      <AuthorizationID xsi:type="ebl:AuthorizationId">1TX27389GX108740X</AuthorizationID>
    </DoReauthorizationResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>  
    RESPONSE
  end
  
  def fraud_review_response
    <<-RESPONSE
    <?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:cc="urn:ebay:apis:CoreComponentTypes" xmlns:wsu="http://schemas.xmlsoap.org/ws/2002/07/utility" xmlns:saml="urn:oasis:names:tc:SAML:1.0:assertion" xmlns:ds="http://www.w3.org/2000/09/xmldsig#" xmlns:wsse="http://schemas.xmlsoap.org/ws/2002/12/secext" xmlns:ebl="urn:ebay:apis:eBLBaseComponents" xmlns:ns="urn:ebay:api:PayPalAPI">
  <SOAP-ENV:Header>
    <Security xmlns="http://schemas.xmlsoap.org/ws/2002/12/secext" xsi:type="wsse:SecurityType"/>
    <RequesterCredentials xmlns="urn:ebay:api:PayPalAPI" xsi:type="ebl:CustomSecurityHeaderType">
      <Credentials xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:UserIdPasswordType">
        <Username xsi:type="xs:string"/>
        <Password xsi:type="xs:string"/>
        <Signature xsi:type="xs:string">An5ns1Kso7MWUdW4ErQKJJJ4qi4-Azffuo82oMt-Cv9I8QTOs-lG5sAv</Signature>
        <Subject xsi:type="xs:string"/>
      </Credentials>
    </RequesterCredentials>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body id="_0">
    <DoDirectPaymentResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-07-04T19:27:39Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">SuccessWithWarning</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">205d8397e7ed</CorrelationID>
      <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
        <ShortMessage xsi:type="xs:string">Payment Pending your review in Fraud Management Filters</ShortMessage>
        <LongMessage xsi:type="xs:string">Payment Pending your review in Fraud Management Filters</LongMessage>
        <ErrorCode xsi:type="xs:token">11610</ErrorCode>
        <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Warning</SeverityCode>
      </Errors>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">50.0</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">623197</Build>
      <Amount xsi:type="cc:BasicAmountType" currencyID="USD">1500.00</Amount>
      <AVSCode xsi:type="xs:string">X</AVSCode>
      <CVV2Code xsi:type="xs:string">M</CVV2Code>
      <TransactionID>5V117995ER6796022</TransactionID>
    </DoDirectPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def failed_capture_due_to_pending_fraud_review
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
    <DoCaptureResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-07-04T21:45:35Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">32a3855bd35b7</CorrelationID>
      <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
        <ShortMessage xsi:type="xs:string">Transaction must be accepted in Fraud Management Filters before capture.</ShortMessage>
        <LongMessage xsi:type="xs:string"/>
        <ErrorCode xsi:type="xs:token">11612</ErrorCode>
        <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
      </Errors>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">52.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">588340</Build>
      <DoCaptureResponseDetails xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:DoCaptureResponseDetailsType">
        <PaymentInfo xsi:type="ebl:PaymentInfoType">
          <TransactionType xsi:type="ebl:PaymentTransactionCodeType">none</TransactionType>
          <PaymentType xsi:type="ebl:PaymentCodeType">none</PaymentType>
          <PaymentStatus xsi:type="ebl:PaymentStatusCodeType">None</PaymentStatus>
          <PendingReason xsi:type="ebl:PendingStatusCodeType">none</PendingReason>
          <ReasonCode xsi:type="ebl:ReversalReasonCodeType">none</ReasonCode>
        </PaymentInfo>
      </DoCaptureResponseDetails>
    </DoCaptureResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end
  
  def authentication_failed_response
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
    <DoDirectPaymentResponse xmlns="urn:ebay:api:PayPalAPI">
      <Timestamp xmlns="urn:ebay:apis:eBLBaseComponents">2008-08-12T19:40:59Z</Timestamp>
      <Ack xmlns="urn:ebay:apis:eBLBaseComponents">Failure</Ack>
      <CorrelationID xmlns="urn:ebay:apis:eBLBaseComponents">b874109bfd11</CorrelationID>
      <Errors xmlns="urn:ebay:apis:eBLBaseComponents" xsi:type="ebl:ErrorType">
        <ShortMessage xsi:type="xs:string">Authentication/Authorization Failed</ShortMessage>
        <LongMessage xsi:type="xs:string">You do not have permissions to make this API call</LongMessage>
        <ErrorCode xsi:type="xs:token">10002</ErrorCode>
        <SeverityCode xmlns="urn:ebay:apis:eBLBaseComponents">Error</SeverityCode>
      </Errors>
      <Version xmlns="urn:ebay:apis:eBLBaseComponents">52.000000</Version>
      <Build xmlns="urn:ebay:apis:eBLBaseComponents">628921</Build>
    </DoDirectPaymentResponse>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_create_profile_paypal_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\">
     <SOAP-ENV:Header>
       <Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security>
       <RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\">
          <Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\">
            <Username xsi:type=\"xs:string\"></Username>
            <Password xsi:type=\"xs:string\"></Password>
            <Signature xsi:type=\"xs:string\"></Signature>
            <Subject xsi:type=\"xs:string\"></Subject></Credentials>
       </RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id=\"_0\">
       <CreateRecurringPaymentsProfileResponse xmlns=\"urn:ebay:api:PayPalAPI\">
         <Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2011-08-28T18:59:40Z</Timestamp>
         <Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack>
         <CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">4b8eaecc084b</CorrelationID>
         <Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">59.0</Version>
         <Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2085867</Build>
       <CreateRecurringPaymentsProfileResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:CreateRecurringPaymentsProfileResponseDetailsType\">
         <ProfileID xsi:type=\"xs:string\">I-G7A2FF8V75JY</ProfileID>
         <ProfileStatus xsi:type=\"ebl:RecurringPaymentsProfileStatusType\">ActiveProfile</ProfileStatus>
         <TransactionID xsi:type=\"xs:string\"></TransactionID></CreateRecurringPaymentsProfileResponseDetails>
       </CreateRecurringPaymentsProfileResponse>
      </SOAP-ENV:Body>
    </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_create_profile_paypal_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\">
    <SOAP-ENV:Header>
      <Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security>
      <RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\">
        <Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\">
          <Username xsi:type=\"xs:string\"></Username>
          <Password xsi:type=\"xs:string\"></Password>
          <Signature xsi:type=\"xs:string\"></Signature>
          <Subject xsi:type=\"xs:string\"></Subject>
        </Credentials>
      </RequesterCredentials>
     </SOAP-ENV:Header>
    <SOAP-ENV:Body id=\"_0\">
    <CreateRecurringPaymentsProfileResponse xmlns=\"urn:ebay:api:PayPalAPI\">
      <Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2011-08-28T18:59:40Z</Timestamp>
      <Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">This is a test failure</Ack>
      <CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">4b8eaecc084b</CorrelationID>
      <Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">59.0</Version>
      <Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2085867</Build>
      <CreateRecurringPaymentsProfileResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:CreateRecurringPaymentsProfileResponseDetailsType\">
        <ProfileID xsi:type=\"xs:string\">I-G7A2FF8V75JY</ProfileID>
        <ProfileStatus xsi:type=\"ebl:RecurringPaymentsProfileStatusType\">ActiveProfile</ProfileStatus>
        <TransactionID xsi:type=\"xs:string\"></TransactionID>
      </CreateRecurringPaymentsProfileResponseDetails>
     </CreateRecurringPaymentsProfileResponse>
    </SOAP-ENV:Body>
   </SOAP-ENV:Envelope>"
   RESPONSE
  end

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


  def successful_update_recurring_payment_profile_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\"><SOAP-ENV:Header><Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security><RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\"><Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\"><Username xsi:type=\"xs:string\"></Username><Password xsi:type=\"xs:string\"></Password><Signature xsi:type=\"xs:string\"></Signature><Subject xsi:type=\"xs:string\"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id=\"_0\">
    <UpdateRecurringPaymentsProfileResponse xmlns=\"urn:ebay:api:PayPalAPI\">
      <Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2012-03-19T20:30:02Z</Timestamp>
      <Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack>
      <CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">9ad0f67c1127c</CorrelationID>
      <Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">72</Version>
      <Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2649250</Build>
      <UpdateRecurringPaymentsProfileResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UpdateRecurringPaymentsProfileResponseDetailsType\">
        <ProfileID xsi:type=\"xs:string\">I-M1L3RX91DPDD</ProfileID>
      </UpdateRecurringPaymentsProfileResponseDetails>
    </UpdateRecurringPaymentsProfileResponse>
  </SOAP-ENV:Body></SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_manage_recurring_payment_profile_response 
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\"><SOAP-ENV:Header><Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security><RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\"><Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\"><Username xsi:type=\"xs:string\"></Username><Password xsi:type=\"xs:string\"></Password><Signature xsi:type=\"xs:string\"></Signature><Subject xsi:type=\"xs:string\"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header>
    <SOAP-ENV:Body id=\"_0\">
    <ManageRecurringPaymentsProfileStatusResponse xmlns=\"urn:ebay:api:PayPalAPI\"><Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2012-03-19T20:41:03Z</Timestamp><Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack><CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">3c02ea62138c4</CorrelationID><Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">72</Version><Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2649250</Build><ManageRecurringPaymentsProfileStatusResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:ManageRecurringPaymentsProfileStatusResponseDetailsType\"><ProfileID xsi:type=\"xs:string\">I-M1L3RX91DPDD</ProfileID></ManageRecurringPaymentsProfileStatusResponseDetails></ManageRecurringPaymentsProfileStatusResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    RESPONSE
  end

  def successful_bill_outstanding_amount
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\"><SOAP-ENV:Header><Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security><RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\"><Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\"><Username xsi:type=\"xs:string\"></Username><Password xsi:type=\"xs:string\"></Password><Signature xsi:type=\"xs:string\"></Signature><Subject xsi:type=\"xs:string\"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id=\"_0\"><BillOutstandingAmountResponse xmlns=\"urn:ebay:api:PayPalAPI\"><Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2012-03-19T20:50:49Z</Timestamp><Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack><CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">2c1cbe06d718e</CorrelationID><Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">72</Version><Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2649250</Build><BillOutstandingAmountResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:BillOutstandingAmountResponseDetailsType\"><ProfileID xsi:type=\"xs:string\">I-M1L3RX91DPDD</ProfileID></BillOutstandingAmountResponseDetails></BillOutstandingAmountResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    RESPONSE
  end

  def succesful_get_recurring_payments_profile_response
    <<-RESPONSE
    <?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xs=\"http://www.w3.org/2001/XMLSchema\" xmlns:cc=\"urn:ebay:apis:CoreComponentTypes\" xmlns:wsu=\"http://schemas.xmlsoap.org/ws/2002/07/utility\" xmlns:saml=\"urn:oasis:names:tc:SAML:1.0:assertion\" xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\" xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xmlns:ed=\"urn:ebay:apis:EnhancedDataTypes\" xmlns:ebl=\"urn:ebay:apis:eBLBaseComponents\" xmlns:ns=\"urn:ebay:api:PayPalAPI\"><SOAP-ENV:Header><Security xmlns=\"http://schemas.xmlsoap.org/ws/2002/12/secext\" xsi:type=\"wsse:SecurityType\"></Security><RequesterCredentials xmlns=\"urn:ebay:api:PayPalAPI\" xsi:type=\"ebl:CustomSecurityHeaderType\"><Credentials xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:UserIdPasswordType\"><Username xsi:type=\"xs:string\"></Username><Password xsi:type=\"xs:string\"></Password><Signature xsi:type=\"xs:string\"></Signature><Subject xsi:type=\"xs:string\"></Subject></Credentials></RequesterCredentials></SOAP-ENV:Header><SOAP-ENV:Body id=\"_0\"><GetRecurringPaymentsProfileDetailsResponse xmlns=\"urn:ebay:api:PayPalAPI\"><Timestamp xmlns=\"urn:ebay:apis:eBLBaseComponents\">2012-03-19T21:34:40Z</Timestamp><Ack xmlns=\"urn:ebay:apis:eBLBaseComponents\">Success</Ack><CorrelationID xmlns=\"urn:ebay:apis:eBLBaseComponents\">6f24b53c49232</CorrelationID><Version xmlns=\"urn:ebay:apis:eBLBaseComponents\">72</Version><Build xmlns=\"urn:ebay:apis:eBLBaseComponents\">2649250</Build><GetRecurringPaymentsProfileDetailsResponseDetails xmlns=\"urn:ebay:apis:eBLBaseComponents\" xsi:type=\"ebl:GetRecurringPaymentsProfileDetailsResponseDetailsType\"><ProfileID xsi:type=\"xs:string\">I-M1L3RX91DPDD</ProfileID><ProfileStatus xsi:type=\"ebl:RecurringPaymentsProfileStatusType\">CancelledProfile</ProfileStatus><Description xsi:type=\"xs:string\">A description</Description><AutoBillOutstandingAmount xsi:type=\"ebl:AutoBillType\">NoAutoBill</AutoBillOutstandingAmount><MaxFailedPayments>0</MaxFailedPayments><RecurringPaymentsProfileDetails xsi:type=\"ebl:RecurringPaymentsProfileDetailsType\"><SubscriberName xsi:type=\"xs:string\">Ryan Bates</SubscriberName><SubscriberShippingAddress xsi:type=\"ebl:AddressType\"><Name xsi:type=\"xs:string\"></Name><Street1 xsi:type=\"xs:string\"></Street1><Street2 xsi:type=\"xs:string\"></Street2><CityName xsi:type=\"xs:string\"></CityName><StateOrProvince xsi:type=\"xs:string\"></StateOrProvince><CountryName></CountryName><Phone xsi:type=\"xs:string\"></Phone><PostalCode xsi:type=\"xs:string\"></PostalCode><AddressID xsi:type=\"xs:string\"></AddressID><AddressOwner xsi:type=\"ebl:AddressOwnerCodeType\">PayPal</AddressOwner><ExternalAddressID xsi:type=\"xs:string\"></ExternalAddressID><AddressStatus xsi:type=\"ebl:AddressStatusCodeType\">Unconfirmed</AddressStatus></SubscriberShippingAddress><BillingStartDate xsi:type=\"xs:dateTime\">2012-03-19T11:00:00Z</BillingStartDate></RecurringPaymentsProfileDetails><CurrentRecurringPaymentsPeriod xsi:type=\"ebl:BillingPeriodDetailsType\"><BillingPeriod xsi:type=\"ebl:BillingPeriodTypeType\">Month</BillingPeriod><BillingFrequency>1</BillingFrequency><TotalBillingCycles>0</TotalBillingCycles><Amount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">1.23</Amount><ShippingAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</ShippingAmount><TaxAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</TaxAmount></CurrentRecurringPaymentsPeriod><RecurringPaymentsSummary xsi:type=\"ebl:RecurringPaymentsSummaryType\"><NumberCyclesCompleted>1</NumberCyclesCompleted><NumberCyclesRemaining>-1</NumberCyclesRemaining><OutstandingBalance xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">1.23</OutstandingBalance><FailedPaymentCount>1</FailedPaymentCount></RecurringPaymentsSummary><CreditCard xsi:type=\"ebl:CreditCardDetailsType\"><CreditCardType xsi:type=\"ebl:CreditCardTypeType\">Visa</CreditCardType><CreditCardNumber xsi:type=\"xs:string\">3576</CreditCardNumber><ExpMonth>1</ExpMonth><ExpYear>2013</ExpYear><CardOwner xsi:type=\"ebl:PayerInfoType\"><PayerStatus xsi:type=\"ebl:PayPalUserStatusCodeType\">unverified</PayerStatus><PayerName xsi:type=\"ebl:PersonNameType\"><FirstName xmlns=\"urn:ebay:apis:eBLBaseComponents\">Ryan</FirstName><LastName xmlns=\"urn:ebay:apis:eBLBaseComponents\">Bates</LastName></PayerName><Address xsi:type=\"ebl:AddressType\"><AddressOwner xsi:type=\"ebl:AddressOwnerCodeType\">PayPal</AddressOwner><AddressStatus xsi:type=\"ebl:AddressStatusCodeType\">Unconfirmed</AddressStatus></Address></CardOwner><StartMonth>0</StartMonth><StartYear>0</StartYear><ThreeDSecureRequest xsi:type=\"ebl:ThreeDSecureRequestType\"></ThreeDSecureRequest></CreditCard><RegularRecurringPaymentsPeriod xsi:type=\"ebl:BillingPeriodDetailsType\"><BillingPeriod xsi:type=\"ebl:BillingPeriodTypeType\">Month</BillingPeriod><BillingFrequency>1</BillingFrequency><TotalBillingCycles>0</TotalBillingCycles><Amount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">1.23</Amount><ShippingAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</ShippingAmount><TaxAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</TaxAmount></RegularRecurringPaymentsPeriod><TrialAmountPaid xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</TrialAmountPaid><RegularAmountPaid xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</RegularAmountPaid><AggregateAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</AggregateAmount><AggregateOptionalAmount xsi:type=\"cc:BasicAmountType\" currencyID=\"USD\">0.00</AggregateOptionalAmount><FinalPaymentDueDate xsi:type=\"xs:dateTime\">1970-01-01T00:00:00Z</FinalPaymentDueDate></GetRecurringPaymentsProfileDetailsResponseDetails></GetRecurringPaymentsProfileDetailsResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
    RESPONSE
  end
end
