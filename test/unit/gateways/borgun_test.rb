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
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300|978", response.authorization
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
    assert_equal "140601083732|11|18|WC0000000001|123456|5|000000012300|978", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/140601083732/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300|978", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/140216103700/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300|978", response.authorization

    refund = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/140216103700/, data)
    end.respond_with(successful_void_response)

    assert_success refund
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
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
