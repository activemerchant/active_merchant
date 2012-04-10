require 'test_helper'

class MyGateTest < Test::Unit::TestCase
  def setup
    @gateway = MyGateGateway.new(
      :merchant_id => '79958a8d-0c7b-4038-8e2e-8948e1d678e1', 
      :application_id => '4b775479-a264-444c-b774-22d5521852d8', 
      :gateway => :fnb_live
    )
    
    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :transaction_index => '25868639-5344-4A62-A722-FB0C22B72658'
    }
  end
  
  def test_security_pre_auth_response
    @gateway.expects(:ssl_post).returns(enrolled_3d_secure_response)
    @options.update :user_agent => '', :http_accept => '*/*'
    
    assert response = @gateway.security_pre_auth(@amount, @credit_card, @options)
    
    assert_instance_of MyGate::SecurityPreAuthResponse, response
    assert_success response
    assert response.enrolled == true
    assert response.transaction_index == 'EFAD257A-C705-4776-9BF9-E7BE5941ACA8'
    assert response.acs_url == 'https://visatest.3dsecure.com/mdpayacs/pareq'
    assert response.pa_request_message == 'eJxVUttuwjAM/ZWK12lN0tILyEQqsDEeQAy2vaIqNdBpvZC2FPb1JKWFLU8+vhzbx4GPg0ScblBUEjkssCjCPRpxNOqdd4mz9bbUZH7f8u0eh1WwxiOHE8oizlLOTGpaQDqoiqU4hGnJIRTH8XzJ+96AOhRICyFBOZ9yen++a7uK4OaGNEyQLy6zsEQgDQCRVWkpL9xjiqUDUMkffijLfEhIXddmctmrElNk5m8IRAeBPEZZVdoqFNk5jvjT92Q3tb8+jy+zfH06vS7ZLhnUQTAO3kdAdAZEioxblKlnU4N5Q4cObQ9I44cw0VNw1+mbnqs2u0HIdZfgHtOhvy5Q6kpMRbdJhwDPeZaiylAy3G2IsBCcGc/GpswkGt0KagYdAPLYafKmxRal0o8xz7cbsRuoqWOlFrN0xxYA0QWkvSNpr62sf7/gCljrrbw='
  end
  
  def test_security_pre_auth_error_response
    @gateway.expects(:ssl_post).returns(error_3d_secure_response)
    @options.update :user_agent => '', :http_accept => '*/*'
    
    assert response = @gateway.security_pre_auth(@amount, @credit_card, @options)
    
    assert_instance_of MyGate::SecurityPreAuthResponse, response
    assert_failure response
    assert response.error_number == 9001
    assert response.error_description == 'Unexpected Error -'
  end
  
  def test_security_auth_response
    @gateway.expects(:ssl_post).returns(successful_security_auth_response)
    
    params  = { 'PaRes' => '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' }
    options = { :transaction_index => 'EFAD257A-C705-4776-9BF9-E7BE5941ACA8' }
    assert response = @gateway.security_auth(params, options)
    
    assert_success response
    assert response.pa_response_status == true
    assert response.signature_verification == true
    assert response.eci == '05'
    assert response.xid == 'GBTqaqwi40CHVMawwY4AYgAABAQ='
    assert response.cavv == 'AAABASOBCAAAAAAAEYEIAAAAAAA='
  end
  
  def test_security_auth_error_response
    @gateway.expects(:ssl_post).returns(failed_security_auth_response)
    
    params  = { 'PaRes' => '' }
    options = { :transaction_index => 'EFAD257A-C705-4776-9BF9-E7BE5941ACA8' }
    assert response = @gateway.security_auth(params, options)
    
    assert_failure response
    assert response.error_number == 9999
    assert response.error_description == 'Unexpected Error - null'
  end
  
  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MyGate::Response, response
    assert_success response
    assert response.test?
    
    assert_equal ['483952'], response.authorization
    assert_equal '50E2B171-BE1F-42FE-B378-DB594DFC3BB0', response.transaction_index
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    
    assert response = @gateway.void(@amount, '50E2B171-BE1F-42FE-B378-DB594DFC3BB0')
    assert_instance_of MyGate::Response, response
    assert_success response
    assert response.test?
    
    assert_equal ['657193'], response.authorization
    assert_equal '9485CA92-5032-43F3-99A6-8D842EF90D90', response.transaction_index
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    assert response = @gateway.capture(@amount, '50E2B171-BE1F-42FE-B378-DB594DFC3BB0')
    assert_instance_of MyGate::Response, response
    assert_success response
    assert response.test?
    
    assert_equal ['951280'], response.authorization
    assert_equal 'CD57C91A-0D30-4CCA-8043-9285B0F7FBE0', response.transaction_index
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    
    assert response = @gateway.refund(@amount, 'CE4778AD-3B7C-4AE7-ABDC-4670B75B5460')
    assert_instance_of MyGate::Response, response
    assert_success response
    assert response.test?
    
    assert_equal ['346030'], response.authorization
    assert_equal 'CE4778AD-3B7C-4AE7-ABDC-4670B75B5460', response.transaction_index
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MyGate::Response, response
    assert_success response
    assert response.test?
    
    # Two transactions happen at once, thus we get two Authorization IDs
    assert_equal ['222471', '984095'], response.authorization
    assert_equal 'DAF69F3C-05A4-4C6F-8066-ECB0C037E465', response.transaction_index
    assert_equal MyGate::Response::SUCCESS, response.message
  end
  
  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'BC70050D-8662-4D5B-B04E-31E56087B99A', response.transaction_index
    assert_equal 'An error occurred while processing the credit card', response.message
  end
  
  def test_warning_capture
    @gateway.expects(:ssl_post).returns(warning_capture_result)
    
    assert response = @gateway.capture(@amount, '50E2B171-BE1F-42FE-B378-DB594DFC3BB0')
    assert_success response
    assert_equal '43CDCDFF-9BB2-4474-91A5-0CF8CFE6D03E', response.transaction_index
    assert_equal 'Warning: Mode was ignored', response.message
  end
  
  private
  
  # This is the response to the call initiated from ActiveMerchant to MyGate for 3D-Secure
  def enrolled_3d_secure_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:lookupResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_3dsecure">
       <lookupReturn soapenc:arrayType="xsd:anyType[5]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <lookupReturn xsi:type="soapenc:string">TransactionIndex||EFAD257A-C705-4776-9BF9-E7BE5941ACA8</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">Result||0</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">Enrolled||Y</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">ACSUrl||https://visatest.3dsecure.com/mdpayacs/pareq</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">PAReqMsg||eJxVUttuwjAM/ZWK12lN0tILyEQqsDEeQAy2vaIqNdBpvZC2FPb1JKWFLU8+vhzbx4GPg0ScblBUEjkssCjCPRpxNOqdd4mz9bbUZH7f8u0eh1WwxiOHE8oizlLOTGpaQDqoiqU4hGnJIRTH8XzJ+96AOhRICyFBOZ9yen++a7uK4OaGNEyQLy6zsEQgDQCRVWkpL9xjiqUDUMkffijLfEhIXddmctmrElNk5m8IRAeBPEZZVdoqFNk5jvjT92Q3tb8+jy+zfH06vS7ZLhnUQTAO3kdAdAZEioxblKlnU4N5Q4cObQ9I44cw0VNw1+mbnqs2u0HIdZfgHtOhvy5Q6kpMRbdJhwDPeZaiylAy3G2IsBCcGc/GpswkGt0KagYdAPLYafKmxRal0o8xz7cbsRuoqWOlFrN0xxYA0QWkvSNpr62sf7/gCljrrbw=</lookupReturn>
       </lookupReturn>
      </ns1:lookupResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  # An example of a response when a required field is missing
  def error_3d_secure_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:lookupResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_3dsecure">
       <lookupReturn soapenc:arrayType="xsd:anyType[3]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <lookupReturn xsi:type="soapenc:string">Result||-1</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">ErrorNo||9001</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">ErrorDesc||Unexpected Error -</lookupReturn>
       </lookupReturn>
      </ns1:lookupResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def not_enrolled_3d_secure_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:lookupResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_3dsecure">
       <lookupReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <lookupReturn xsi:type="soapenc:string">TransactionIndex||EEA3E083-4A46-4F8B-B819-6C5B1621052F</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">Result||0</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">Enrolled||N</lookupReturn>
        <lookupReturn xsi:type="soapenc:string">ECI||06</lookupReturn>
       </lookupReturn>
      </ns1:lookupResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessAndSettleResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessAndSettleReturn soapenc:arrayType="xsd:anyType[5]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessAndSettleReturn xsi:type="soapenc:string">Result||0</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">TransactionIndex||daf69f3c-05a4-4c6f-8066-ecb0c037e465</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/02 11:19:41 AM</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">AuthorisationID||222471</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">AuthorisationID||984095</fProcessAndSettleReturn>
       </fProcessAndSettleReturn>
      </ns1:fProcessAndSettleResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_security_auth_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:authenticateResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_3dsecure">
       <authenticateReturn soapenc:arrayType="xsd:anyType[6]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <authenticateReturn xsi:type="soapenc:string">Result||0</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">PAResStatus||Y</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">SignatureVerification||Y</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">XID||GBTqaqwi40CHVMawwY4AYgAABAQ=</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">Cavv||AAABASOBCAAAAAAAEYEIAAAAAAA=</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">ECI||05</authenticateReturn>
       </authenticateReturn>
      </ns1:authenticateResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def failed_security_auth_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:authenticateResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_3dsecure">
       <authenticateReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <authenticateReturn xsi:type="soapenc:string">Result||-1</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">ErrorNo||9999</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">ErrorDesc||Unexpected Error - null</authenticateReturn>
        <authenticateReturn xsi:type="soapenc:string">ECI||07</authenticateReturn>
       </authenticateReturn>
      </ns1:authenticateResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def failed_purchase_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessAndSettleResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessAndSettleReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessAndSettleReturn xsi:type="soapenc:string">Result||-1</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">TransactionIndex||bc70050d-8662-4d5b-b04e-31e56087b99a</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">Error||5001||Service.Processing||Processing Error||An error occurred while processing the credit card</fProcessAndSettleReturn>
        <fProcessAndSettleReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/02 12:11:38 PM</fProcessAndSettleReturn>
       </fProcessAndSettleReturn>
      </ns1:fProcessAndSettleResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_authorize_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessReturn xsi:type="soapenc:string">Result||0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">TransactionIndex||50e2b171-be1f-42fe-b378-db594dfc3bb0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/05 11:38:44 AM</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AuthorisationID||483952</fProcessReturn>
       </fProcessReturn>
      </ns1:fProcessResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_capture_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessReturn xsi:type="soapenc:string">Result||0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">TransactionIndex||cd57c91a-0d30-4cca-8043-9285b0f7fbe0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/08 01:46:47 PM</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AuthorisationID||951280</fProcessReturn>
       </fProcessReturn>
      </ns1:fProcessResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_refund_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessReturn xsi:type="soapenc:string">Result||0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">TransactionIndex||ce4778ad-3b7c-4ae7-abdc-4670b75b5460</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/09 11:34:57 AM</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AuthorisationID||346030</fProcessReturn>
       </fProcessReturn>
      </ns1:fProcessResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def successful_void_response
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessReturn soapenc:arrayType="xsd:anyType[4]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessReturn xsi:type="soapenc:string">Result||0</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">TransactionIndex||9485ca92-5032-43f3-99a6-8d842ef90d90</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/09 10:45:54 AM</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AuthorisationID||657193</fProcessReturn>
       </fProcessReturn>
      </ns1:fProcessResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
  
  def warning_capture_result
    %(<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
     <soapenv:Body>
      <ns1:fProcessResponse soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="http://_5x0x0.enterprise">
       <fProcessReturn soapenc:arrayType="xsd:anyType[5]" xsi:type="soapenc:Array" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">
        <fProcessReturn xsi:type="soapenc:string">Result||1</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">TransactionIndex||43cdcdff-9bb2-4474-91a5-0cf8cfe6d03e</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">Warning||8001||Service.Validate||Mode was ignored||</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AcquirerDateTime||2011/12/08 01:46:20 PM</fProcessReturn>
        <fProcessReturn xsi:type="soapenc:string">AuthorisationID||417224</fProcessReturn>
       </fProcessReturn>
      </ns1:fProcessResponse>
     </soapenv:Body>
    </soapenv:Envelope>)
  end
end
