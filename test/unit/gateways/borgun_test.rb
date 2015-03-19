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

    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300", response.authorization
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
    assert_equal "140601083732|11|18|WC0000000001|123456|5|000000012300", response.authorization

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
    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300", response.authorization

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
    assert_equal "140216103700|11|15|WC0000000001|123456|1|000000012300", response.authorization

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
end
