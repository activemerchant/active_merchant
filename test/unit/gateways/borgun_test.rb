require 'test_helper'

class BorgunTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BorgunGateway.new(
      processor: '118',
      merchant_id: '118',
      username: 'dude',
      password: 'secret'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      terminal_id: '3'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '140216103700|11|15|WC0000000001|123456|1|000000012300|978', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '140601083732|11|18|WC0000000001|123456|5|000000012300|978', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/140601083732/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_preauth_3ds
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ redirect_url: 'http://localhost/index.html', apply_3d_secure: '1', sale_description: 'product description' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/MerchantReturnURL&gt;#{@options[:redirect_url]}/, data)
      assert_match(/SaleDescription&gt;#{@options[:sale_description]}/, data)
      assert_match(/TrCurrencyExponent&gt;2/, data)
    end.respond_with(failed_get_3ds_authentication_response)

    assert_failure response
    assert_equal response.message, 'Exception in PostEnrollmentRequest.'
    assert response.authorization.blank?
  end

  def test_successful_preauth_3ds
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ redirect_url: 'http://localhost/index.html', apply_3d_secure: '1', sale_description: 'product description' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/MerchantReturnURL&gt;#{@options[:redirect_url]}/, data)
      assert_match(/SaleDescription&gt;#{@options[:sale_description]}/, data)
      assert_match(/TrCurrencyExponent&gt;2/, data)
    end.respond_with(successful_get_3ds_authentication_response)

    assert_success response
    assert !response.params['redirecttoacsform'].blank?
    assert !response.params['acsformfields_actionurl'].blank?
    assert !response.params['acsformfields_pareq'].blank?
    assert !response.params['threedsmessageid'].blank?
    assert response.authorization.blank?
  end

  def test_successful_purchase_after_3ds
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ three_ds_message_id: '98324_zzi_1234353' }))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/ThreeDSMessageId&gt;#{@options[:three_ds_message_id]}/, data)
      assert_match(/TrCurrencyExponent&gt;0/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_authorize_airline_data
    # itinerary data abbreviated for brevity
    passenger_itinerary_data = {
      'MessageNumber' => '1111111',
      'TrDate' => '20120222',
      'TrTime' => '151515',
      'PassengerName' => 'Jane Doe'
    }
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, { passenger_itinerary_data: passenger_itinerary_data })
    end.check_request do |_endpoint, data, _headers|
      assert_match('PassengerItineraryData', data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '140216103700|11|15|WC0000000001|123456|1|000000012300|978', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/140216103700/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '140216103700|11|15|WC0000000001|123456|1|000000012300|978', response.authorization

    refund = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/140216103700/, data)
    end.respond_with(successful_void_response)

    assert_success refund
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_terminal_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, { terminal_id: '3' })
    end.check_request do |_endpoint, data, _headers|
      assert_match(/TerminalID&gt;3/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:getAuthorizationOutput xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuthResXml>&lt;?xml version="1.0" encoding="iso-8859-1"?&gt;
      &lt;getAuthorizationReply&gt;
        &lt;Version&gt;1000&lt;/Version&gt;
        &lt;Processor&gt;118&lt;/Processor&gt;
        &lt;MerchantID&gt;118&lt;/MerchantID&gt;
        &lt;TerminalID&gt;1&lt;/TerminalID&gt;
        &lt;TransType&gt;1&lt;/TransType&gt;
        &lt;TrAmount&gt;000000012300&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140216103700&lt;/DateAndTime&gt;
        &lt;PAN&gt;4507280000053760&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;Transaction&gt;15&lt;/Transaction&gt;
        &lt;Batch&gt;11&lt;/Batch&gt;
        &lt;CardAccId&gt;9256684&lt;/CardAccId&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\IS&lt;/CardAccName&gt;
        &lt;AuthCode&gt;123456&lt;/AuthCode&gt;
        &lt;ActionCode&gt;000&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
        &lt;CardType&gt;Visa&lt;/CardType&gt;
      &lt;/getAuthorizationReply&gt;</getAuthResXml>
      </ser-root:getAuthorizationOutput></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def successful_authorize_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:getAuthorizationOutput xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuthResXml>&lt;?xml version="1.0" encoding="utf-8"?&gt;
      &lt;getAuthorizationReply&gt;
        &lt;Version&gt;1000&lt;/Version&gt;
        &lt;Processor&gt;118&lt;/Processor&gt;
        &lt;MerchantID&gt;118&lt;/MerchantID&gt;
        &lt;TerminalID&gt;1&lt;/TerminalID&gt;
        &lt;TransType&gt;5&lt;/TransType&gt;
        &lt;TrAmount&gt;000000012300&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140601083732&lt;/DateAndTime&gt;
        &lt;PAN&gt;4507280000053760&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;Transaction&gt;18&lt;/Transaction&gt;
        &lt;Batch&gt;11&lt;/Batch&gt;
        &lt;CardAccId&gt;9256684&lt;/CardAccId&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\IS&lt;/CardAccName&gt;
        &lt;AuthCode&gt;123456&lt;/AuthCode&gt;
        &lt;ActionCode&gt;000&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
        &lt;CardType&gt;Visa&lt;/CardType&gt;
      &lt;/getAuthorizationReply&gt;</getAuthResXml>
      </ser-root:getAuthorizationOutput></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def successful_capture_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:getAuthorizationOutput xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuthResXml>&lt;?xml version="1.0" encoding="utf-8"?&gt;
      &lt;getAuthorizationReply&gt;
        &lt;Version&gt;1000&lt;/Version&gt;
        &lt;Processor&gt;118&lt;/Processor&gt;
        &lt;MerchantID&gt;118&lt;/MerchantID&gt;
        &lt;TerminalID&gt;1&lt;/TerminalID&gt;
        &lt;TransType&gt;1&lt;/TransType&gt;
        &lt;TrAmount&gt;100000&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;352&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140501083700&lt;/DateAndTime&gt;
        &lt;PAN&gt;5587402000012011&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;Transaction&gt;57&lt;/Transaction&gt;
        &lt;Batch&gt;11&lt;/Batch&gt;
        &lt;CardAccId/&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\IS&lt;/CardAccName&gt;
        &lt;AuthCode&gt;048454&lt;/AuthCode&gt;
        &lt;ActionCode&gt;000&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
        &lt;CardType&gt;MasterCard&lt;/CardType&gt;
      &lt;/getAuthorizationReply&gt;</getAuthResXml>
      </ser-root:getAuthorizationOutput></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def successful_refund_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:getAuthorizationOutput xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuthResXml>&lt;?xml version="1.0" encoding="iso-8859-1"?&gt;
      &lt;getAuthorizationReply&gt;
        &lt;Version&gt;1000&lt;/Version&gt;
        &lt;Processor&gt;118&lt;/Processor&gt;
        &lt;MerchantID&gt;118&lt;/MerchantID&gt;
        &lt;TerminalID&gt;1&lt;/TerminalID&gt;
        &lt;TransType&gt;3&lt;/TransType&gt;
        &lt;TrAmount&gt;100000&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;352&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140216103701&lt;/DateAndTime&gt;
        &lt;PAN&gt;5587402000012011&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;Transaction&gt;54&lt;/Transaction&gt;
        &lt;Batch&gt;11&lt;/Batch&gt;
        &lt;CardAccId&gt;9256684&lt;/CardAccId&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\IS&lt;/CardAccName&gt;
        &lt;AuthCode&gt;048443&lt;/AuthCode&gt;
        &lt;ActionCode&gt;000&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
        &lt;CardType&gt;MasterCard&lt;/CardType&gt;
      &lt;/getAuthorizationReply&gt;</getAuthResXml>
      </ser-root:getAuthorizationOutput></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def failed_purchase_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:getAuthorizationOutput xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuthResXml>&lt;?xml version="1.0" encoding="iso-8859-1"?&gt;
      &lt;getAuthorizationReply&gt;
        &lt;TrAmount&gt;000000012300&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140216103700&lt;/DateAndTime&gt;
        &lt;PAN&gt;6799999999593&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;CardAccId&gt;9256684&lt;/CardAccId&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\IS&lt;/CardAccName&gt;
        &lt;AuthCode&gt;123456&lt;/AuthCode&gt;
        &lt;ActionCode&gt;111&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
        &lt;CardType&gt;MasterCard&lt;/CardType&gt;
      &lt;/getAuthorizationReply&gt;</getAuthResXml>
      </ser-root:getAuthorizationOutput></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def successful_void_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:cancelAuthorizationResponse xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <cancelAuthResXml>&lt;?xml version="1.0" encoding="iso-8859-1"?&gt;
      &lt;cancelAuthorizationReply&gt;
        &lt;Version&gt;1000&lt;/Version&gt;
        &lt;Processor&gt;118&lt;/Processor&gt;
        &lt;MerchantID&gt;118&lt;/MerchantID&gt;
        &lt;TerminalID&gt;1&lt;/TerminalID&gt;
        &lt;TransType&gt;5&lt;/TransType&gt;
        &lt;TrAmount&gt;000000012300&lt;/TrAmount&gt;
        &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;
        &lt;DateAndTime&gt;140501083806&lt;/DateAndTime&gt;
        &lt;PAN&gt;5587402000012011&lt;/PAN&gt;
        &lt;RRN&gt;WC0000000001&lt;/RRN&gt;
        &lt;Transaction&gt;184&lt;/Transaction&gt;
        &lt;Batch&gt;11&lt;/Batch&gt;
        &lt;CardAccName&gt;Spreedly\Armuli 30\Reykjavik\108\\352&lt;/CardAccName&gt;
        &lt;AuthCode&gt;057457&lt;/AuthCode&gt;
        &lt;ActionCode&gt;000&lt;/ActionCode&gt;
        &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;
      &lt;/cancelAuthorizationReply&gt;</cancelAuthResXml>
      </ser-root:cancelAuthorizationResponse></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def successful_get_3ds_authentication_response
    <<~RESPONSE
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <get3DSAuthenticationReply>
        <Status>
          <ResultCode>0</ResultCode>
          <ResultText/>
        </Status>
        <Version>1000</Version>
        <Processor>23</Processor>
        <MerchantID>23</MerchantID>
        <ThreeDSMessageId>23_20201408041400003</ThreeDSMessageId>
        <ThreeDSStatus>9</ThreeDSStatus>
        <ThreeDSMessage>ToberedirectedtoACS</ThreeDSMessage>
        <EnrollmentStatus>Y</EnrollmentStatus>
        <RedirectToACSForm>3C21444F43545950452068746D6C2053595354454D202261626F75743A6C65676163792D636F6D706174223E0D0D0A3C68746D6C20636C6173733D226E6F2D6A7322206C616E673D22656E2220786D6C6E733D22687474703A2F2F7777772E77332E6F72672F313939392F7868746D6C223E0D0D0A3C686561643E0D0D0A3C6D65746120687474702D65717569763D22436F6E74656E742D547970652220636F6E74656E743D22746578742F68746D6C3B20636861727365743D7574662D38222F3E0D0D0A3C6D65746120636861727365743D227574662D38222F3E0D0D0A3C7469746C653E3344205365637572652050726F63657373696E673C2F7469746C653E0D0D0A3C6C696E6B20687265663D2268747470733A2F2F6D70692E626F7267756E2E69732F6D647061796D70692F7374617469632F6D70692E637373222072656C3D227374796C6573686565742220747970653D22746578742F637373222F3E0D0D0A3C2F686561643E0D0D0A3C626F64793E0D0D0A3C6469762069643D226D61696E223E0D0D0A3C6469762069643D22636F6E74656E74223E0D0D0A3C6469762069643D226F72646572223E0D0D0A3C68323E3344205365637572652050726F63657373696E673C2F68323E0D0D0A3C696D67207372633D2268747470733A2F2F6D70692E626F7267756E2E69732F6D647061796D70692F7374617469632F7072656C6F616465722E6769662220616C743D22506C6561736520776169742E2E222F3E0D0D0A3C696D67207372633D2268747470733A2F2F6D70692E626F7267756E2E69732F6D647061796D70692F7374617469632F6D635F6964636865636B5F68727A5F6C74645F706F735F31303370782E706E672220616C743D224D61737465724361726420494420436865636B222F3E0D0D0A3C6469762069643D22666F726D646976223E0D0D0A3C73637269707420747970653D22746578742F6A617661736372697074223E0D0D0A66756E6374696F6E2068696465416E645375626D697454696D656428666F726D6964290D0D0A7B0D0D0A7661722074696D65723D73657454696D656F7574282268696465416E645375626D69742827222B666F726D69642B2227293B222C313030293B0D0D0A7D0D0D0A0D0D0A66756E6374696F6E2068696465416E645375626D697428666F726D6964290D0D0A7B0D0D0A76617220666F726D783D646F63756D656E742E676574456C656D656E744279496428666F726D6964293B0D0D0A0969662028666F726D78213D6E756C6C290D0D0A097B0D0D0A09666F726D782E7374796C652E7669736962696C6974793D2268696464656E223B0D0D0A09666F726D782E7375626D697428293B0D0D0A097D0D0D0A7D0D0D0A3C2F7363726970743E0D0D0A3C6469763E0D0D0A3C666F726D2069643D22776562666F726D3022206E616D653D2272656432414353763122206D6574686F643D22504F53542220616374696F6E3D2268747470733A2F2F616373312E3364732E6D6F646972756D2E636F6D2F6D647061796163732F706172657122206163636570745F636861727365743D225554462D38223E0D0D0A3C696E70757420747970653D2268696464656E22206E616D653D225F636861727365745F222076616C75653D225554462D38222F3E0D0D0A3C696E70757420747970653D2268696464656E22206E616D653D225061526571222076616C75653D22654A785655753175676A4155665258692F396D57723443354E7346684D724C676D4F7746574C6C427A437861697445392F56715575663237353979766E6E4D4C487A75466D4A596F426F556363757A37716B476E725A657A5976764F614F4146455976634759636932654B4A77786C5633336153737A6D647530416D614471563246565363366A45615A5674654F417A502F4B4133434563554755706A39306744434D6679413243724137495635317142756B384F586D52505A56765365466F374855724779426A486B5133534B32753341764D79676E416F4C37345475766A6770445063634B383759465946736A6A4F6356676F39354D756251317A2F664A4E552B5449452B627932612F706E6D6166322F53684F587065676E45566B42646165517564536D4E61655377634D4838425456435268367167313350732F4C56595A51616554634D5237736D75594578385A6341343635434B53594645774B384844754A707349302F4D5A51597939346F627036454E6F70555A31626755625A53414E354348702B7357344C6259786B4E4B4978382B4B5157636448796735766A5538756F3279636267455132305475787954336535766F337A2F34415552317277553D222F3E0D0D0A3C696E70757420747970653D2268696464656E22206E616D653D224D44222076616C75653D2232335F3230323031343038303431343030303033222F3E0D0D0A3C696E70757420747970653D2268696464656E22206E616D653D225465726D55726C222076616C75653D22687474703A2F2F6C6F63616C686F73742F696E6465782E68746D6C222F3E0D0D0A3C696E70757420747970653D227375626D697422206E616D653D227375626D697442746E222076616C75653D22506C6561736520636C69636B206865726520746F20636F6E74696E7565222F3E0D0D0A3C2F666F726D3E0D0D0A3C2F6469763E0D0D0A3C2F6469763E0D0D0A3C73637269707420747970653D22746578742F6A617661736372697074223E0D0D0A09090968696465416E645375626D697454696D65642827776562666F726D3027293B0D0D0A09093C2F7363726970743E0D0D0A3C6E6F7363726970743E0D0D0A3C64697620616C69676E3D2263656E746572223E0D0D0A3C623E4A617661736372697074206973207475726E6564206F6666206F72206E6F7420737570706F72746564213C2F623E0D0D0A3C62722F3E0D0D0A3C2F6469763E0D0D0A3C2F6E6F7363726970743E0D0D0A3C2F6469763E0D0D0A3C6469762069643D22636F6E74656E742D666F6F746572223E0D0D0A3C62722F3E0D0D0A3C696D67206865696768743D22323022207372633D2268747470733A2F2F6D70692E626F7267756E2E69732F6D647061796D70692F7374617469632F706F77657265642D62792D6D6F646972756D2E7376672220616C743D22506F7765726564206279204D6F646972756D222F3E0D0D0A3C2F6469763E0D0D0A3C2F6469763E0D0D0A3C2F6469763E0D0D0A3C2F626F64793E0D0D0A3C2F68746D6C3E0D0D0A
        </RedirectToACForm>
        <ACSFormFields>
          <actionURL>https://acs1.3ds.modirum.com/mdpayacs/pareq</actionURL>
          <PaReq>eJxVUu1ugjAUfRXi/9mWr4C5NsFhMrLgmOwFWLlBzCxaitE9/VqUuf2759yvnnMLHzuFmJYoBoUccuz7qkGnrZezYvvOaOAFEYvcGYci2eKJwxlV33aSszmdu0AmaDqV2FVSc6jEaZVteOAzP/KA3CEcUGUpj90gDCMfyA2CrA7IV51qBuk8OXmRPZVvSeFo7HUrGyBjHkQ3SK2u3AvMygnAoL74TuvjgpDPccK87YFYFsjjOcVgo95MubQ1z/fJNU+TIE+by2a/pnmaf2/ShOXpegnEVkBdaeQudSmNaeSwcMH8BTVCRh6qg13Ps/LVYZQaeTcMR7smuYEx8ZcA465CKSYFEwK8HDuJpsI0/MZQYy94obp6ENopUZ1bgUbZSAN5CHp+sW4LbYxkNKIx8+KQWcdHyg5vjU8uo2ycbgEQ20TuxyT3e5vo3z/4AUR1rwU=</PaReq>
          <MerchantReturnURL>http://localhost/index.html</MerchantReturnURL>
        </ACSFormFields>
      </get3DSAuthenticationReply>
      </SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    RESPONSE
  end

  def failed_get_3ds_authentication_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <SOAP-ENV:Header xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"></SOAP-ENV:Header><SOAP-ENV:Body>
      <ser-root:get3DSAuthenticationResponse xmlns:ser-root="http://Borgun/Heimir/pub/ws/Authorization" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <getAuth3DSResXml>&lt;?xml version="1.0" encoding="iso-8859-1"?&gt;
      &lt;get3DSAuthenticationReply&gt;
        &lt;Status&gt;
        &lt;ResultCode&gt;30&lt;/ResultCode&gt;
        &lt;ResultText&gt;MPI returns error&lt;/ResultText&gt;
        &lt;ErrorMessage&gt;Exception in PostEnrollmentRequest.&lt;/ErrorMessage&gt;
        &lt;/Status&gt;
      &lt;/get3DSAuthenticationReply&gt;</getAuth3DSResXml>
      </ser-root:get3DSAuthenticationResponse></SOAP-ENV:Body>
      </SOAP-ENV:Envelope>
    )
  end

  def transcript
    <<-PRE_SCRUBBED
    <- "POST /ws/Heimir.pub.ws:Authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic yyyyyyyyyyyyyyyyyyyyyyyyyy==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway01.borgun.is\r\nContent-Length: 1220\r\n\r\n"
    <- "          <soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:aut=\"http://Borgun/Heimir/pub/ws/Authorization\">\n            <soapenv:Header/>\n            <soapenv:Body>\n              <aut:getAuthorizationInput>\n                <getAuthReqXml>\n                &lt;?xml version=&quot;1.0&quot; encoding=&quot;utf-8&quot;?&gt;\n&lt;getAuthorization&gt;\n                  &lt;TransType&gt;1&lt;/TransType&gt;\n                  &lt;TrAmount&gt;12600&lt;/TrAmount&gt;\n                  &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;\n                  &lt;PAN&gt;4111111111111111&lt;/PAN&gt;\n                  &lt;ExpDate&gt;1705&lt;/ExpDate&gt;\n                  &lt;CVC2&gt;123&lt;/CVC2&gt;\n                  &lt;DateAndTime&gt;141110215924&lt;/DateAndTime&gt;\n                  &lt;RRN&gt;AMRCNT158463&lt;/RRN&gt;\n                  &lt;Version&gt;1000&lt;/Version&gt;\n                  &lt;Processor&gt;938&lt;/Processor&gt;\n                  &lt;MerchantID&gt;938&lt;/MerchantID&gt;\n                  &lt;TerminalID&gt;1&lt;/TerminalID&gt;\n&lt;/getAuthorization&gt;\n\n                </getAuthReqXml>\n              </aut:getAuthorizationInput>\n            </soapenv:Body>\n          </soapenv:Envelope>\n"
    -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<SOAP-ENV:Header xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"></SOAP-ENV:Header><SOAP-ENV:Body>\n<ser-root:getAuthorizationOutput xmlns:ser-root=\"http://Borgun/Heimir/pub/ws/Authorization\">\n  <getAuthResXml>&lt;?xml version=\"1.0\" encoding=\"iso-8859-1\"?&gt;\n&lt;getAuthorizationReply&gt;\n  &lt;Version&gt;1000&lt;/Version&gt;\n  &lt;Processor&gt;938&lt;/Processor&gt;\n  &lt;MerchantID&gt;938&lt;/MerchantID&gt;\n  &lt;TerminalID&gt;1&lt;/TerminalID&gt;\n  &lt;TransType&gt;1&lt;/TransType&gt;\n  &lt;TrAmount&gt;000000012600&lt;/TrAmount&gt;\n  &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;\n  &lt;DateAndTime&gt;141110215924&lt;/DateAndTime&gt;\n  &lt;PAN&gt;4111111111111111&lt;/PAN&gt;\n  &lt;RRN&gt;AMRCNT158463&lt;/RRN&gt;\n  &lt;Transaction&gt;22&lt;/Transaction&gt;\n  &lt;Batch&gt;263&lt;/Batch&gt;\n  &lt;CVCResult&gt;M&lt;/CVCResult&gt;\n  &lt;CardAccId&gt;9858674&lt;/CardAccId&gt;\n  &lt;CardAccName&gt;Longbob+Longsen\xC3\xADk\\101\\\\IS&lt;/CardAccName&gt;\n  &lt;AuthCode&gt;114031&lt;/AuthCode&gt;\n  &lt;ActionCode&gt;000&lt;/ActionCode&gt;\n  &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;\n  &lt;CardType&gt;Visa&lt;/CardType&gt;\n&lt;/getAuthorizationReply&gt;</getAuthResXml>\n</ser-root:getAuthorizationOutput></SOAP-ENV:Body>\n</SOAP-ENV:Envelope>\n"
    PRE_SCRUBBED
  end

  def scrubbed_transcript
    <<-POST_SCRUBBED
    <- "POST /ws/Heimir.pub.ws:Authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway01.borgun.is\r\nContent-Length: 1220\r\n\r\n"
    <- "          <soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:aut=\"http://Borgun/Heimir/pub/ws/Authorization\">\n            <soapenv:Header/>\n            <soapenv:Body>\n              <aut:getAuthorizationInput>\n                <getAuthReqXml>\n                &lt;?xml version=&quot;1.0&quot; encoding=&quot;utf-8&quot;?&gt;\n&lt;getAuthorization&gt;\n                  &lt;TransType&gt;1&lt;/TransType&gt;\n                  &lt;TrAmount&gt;12600&lt;/TrAmount&gt;\n                  &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;\n                  &lt;PAN&gt;[FILTERED]&lt;/PAN&gt;\n                  &lt;ExpDate&gt;1705&lt;/ExpDate&gt;\n                  &lt;CVC2&gt;[FILTERED]&lt;/CVC2&gt;\n                  &lt;DateAndTime&gt;141110215924&lt;/DateAndTime&gt;\n                  &lt;RRN&gt;AMRCNT158463&lt;/RRN&gt;\n                  &lt;Version&gt;1000&lt;/Version&gt;\n                  &lt;Processor&gt;938&lt;/Processor&gt;\n                  &lt;MerchantID&gt;938&lt;/MerchantID&gt;\n                  &lt;TerminalID&gt;1&lt;/TerminalID&gt;\n&lt;/getAuthorization&gt;\n\n                </getAuthReqXml>\n              </aut:getAuthorizationInput>\n            </soapenv:Body>\n          </soapenv:Envelope>\n"
    -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n<SOAP-ENV:Header xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"></SOAP-ENV:Header><SOAP-ENV:Body>\n<ser-root:getAuthorizationOutput xmlns:ser-root=\"http://Borgun/Heimir/pub/ws/Authorization\">\n  <getAuthResXml>&lt;?xml version=\"1.0\" encoding=\"iso-8859-1\"?&gt;\n&lt;getAuthorizationReply&gt;\n  &lt;Version&gt;1000&lt;/Version&gt;\n  &lt;Processor&gt;938&lt;/Processor&gt;\n  &lt;MerchantID&gt;938&lt;/MerchantID&gt;\n  &lt;TerminalID&gt;1&lt;/TerminalID&gt;\n  &lt;TransType&gt;1&lt;/TransType&gt;\n  &lt;TrAmount&gt;000000012600&lt;/TrAmount&gt;\n  &lt;TrCurrency&gt;978&lt;/TrCurrency&gt;\n  &lt;DateAndTime&gt;141110215924&lt;/DateAndTime&gt;\n  &lt;PAN&gt;[FILTERED]&lt;/PAN&gt;\n  &lt;RRN&gt;AMRCNT158463&lt;/RRN&gt;\n  &lt;Transaction&gt;22&lt;/Transaction&gt;\n  &lt;Batch&gt;263&lt;/Batch&gt;\n  &lt;CVCResult&gt;M&lt;/CVCResult&gt;\n  &lt;CardAccId&gt;9858674&lt;/CardAccId&gt;\n  &lt;CardAccName&gt;Longbob+Longsen\xC3\xADk\\101\\\\IS&lt;/CardAccName&gt;\n  &lt;AuthCode&gt;114031&lt;/AuthCode&gt;\n  &lt;ActionCode&gt;000&lt;/ActionCode&gt;\n  &lt;StoreTerminal&gt;00010001&lt;/StoreTerminal&gt;\n  &lt;CardType&gt;Visa&lt;/CardType&gt;\n&lt;/getAuthorizationReply&gt;</getAuthResXml>\n</ser-root:getAuthorizationOutput></SOAP-ENV:Body>\n</SOAP-ENV:Envelope>\n"
    POST_SCRUBBED
  end
end
