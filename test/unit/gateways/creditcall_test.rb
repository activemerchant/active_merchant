require 'test_helper'

class CreditcallTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CreditcallGateway.new(terminal_id: 'login', transaction_key: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '86dd2c0f-b742-e511-b302-00505692354f', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, "bc8e3abe-b842-e511-b302-00505692354f", @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "", @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, "77e55712-ba42-e511-b302-00505692354f", @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "", @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void("e5b1b672-ba42-e511-b302-00505692354f", @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("", @options)
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_verification_value_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r(<CSC>123</CSC>)m, data)
    end.respond_with(successful_authorize_response)
  end

  def test_verification_value_not_sent
    @credit_card.verification_value = "  "
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/CSC/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_options_add_avs_additional_verification_fields
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/AdditionalVerification/, data)
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(verify_zip: 'false', verify_address: 'false'))
    end.check_request do |endpoint, data, headers|
      assert_no_match(/AdditionalVerification/, data)
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(verify_zip: 'true', verify_address: 'true'))
    end.check_request do |endpoint, data, headers|
      assert_match(/<AdditionalVerification>\n      <Zip>K1C2N6<\/Zip>\n      <Address>/, data)
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(verify_zip: 'true', verify_address: 'false'))
    end.check_request do |endpoint, data, headers|
      assert_match(/ <AdditionalVerification>\n      <Zip>K1C2N6<\/Zip>\n    <\/AdditionalVerification>\n/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
    <?xml version=\"1.0\"?>\n<Request type=\"CardEaseXML\" version=\"1.0.0\">\n  <TransactionDetails>\n    <MessageType>Auth</MessageType>\n    <Amount unit=\"Minor\">100</Amount>\n  </TransactionDetails>\n  <TerminalDetails>\n    <TerminalID>99961426</TerminalID>\n    <TransactionKey>9drdRU9wJ65SNRw3</TransactionKey>\n    <Software version=\"SoftwareVersion\">SoftwareName</Software>\n  </TerminalDetails>\n  <CardDetails>\n    <Manual type=\"cnp\">\n      <PAN>4000100011112224</PAN>\n      <ExpiryDate format=\"yyMM\">1609</ExpiryDate>\n      <CSC>123</CSC>\n    </Manual>\n  </CardDetails>\n</Request>\n
    )
  end

  def post_scrubbed
    %q(
    <?xml version=\"1.0\"?>\n<Request type=\"CardEaseXML\" version=\"1.0.0\">\n  <TransactionDetails>\n    <MessageType>Auth</MessageType>\n    <Amount unit=\"Minor\">100</Amount>\n  </TransactionDetails>\n  <TerminalDetails>\n    <TerminalID>99961426</TerminalID>\n    <TransactionKey>[FILTERED]</TransactionKey>\n    <Software version=\"SoftwareVersion\">SoftwareName</Software>\n  </TerminalDetails>\n  <CardDetails>\n    <Manual type=\"cnp\">\n      <PAN>[FILTERED]</PAN>\n      <ExpiryDate format=\"yyMM\">1609</ExpiryDate>\n      <CSC>[FILTERED]</CSC>\n    </Manual>\n  </CardDetails>\n</Request>\n
    )
  end

  def successful_purchase_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>0999da90-b342-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814143753</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814183753</UTC></TransactionDetails><Result><LocalResult>0</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity></Result><CardDetails><CardReference>c2c5fa63-3dd1-da11-8531-01422187e37</CardReference><CardHash>8CtuNPQnryhFt6amPWtp6PLZYXI=</CardHash><PAN>341111xxxxx1002</PAN><ExpiryDate format=”yyMM”>2012</ExpiryDate><CardScheme><Description>AMEX</Description></CardScheme></CardDetails></Response>
    )
  end

  def failed_purchase_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>55ec5427-b642-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814145622</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814185622</UTC></TransactionDetails><Result><LocalResult>1</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity><Errors><Error code=\"1001\">ExpiredCard</Error></Errors></Result><CardDetails><CardReference>2468f656-9242-e511-ab11-002219649f24</CardReference><CardHash>WSknCJJIvbog334uwCNWUKE9ZbI=</CardHash><PAN>xxxxxxxxxxxx2220</PAN><ExpiryDate format=\"yyMM\">1609</ExpiryDate><CardScheme><Description>VISA</Description></CardScheme></CardDetails></Response>"
    )
  end

  def successful_authorize_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>86dd2c0f-b742-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814150251</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814190251</UTC></TransactionDetails><Result><LocalResult>0</LocalResult><AuthCode>5ECC4B</AuthCode><AuthorisationEntity>Unknown</AuthorisationEntity><AmountOnlineApproved unit=\"major\">1.00</AmountOnlineApproved></Result><CardDetails><CardReference>ed79bf2f-6d3c-e511-ab11-002219649f24</CardReference><CardHash>YO5CqO1QQbHbMaFRuSV2vVq7uqQ=</CardHash><PAN>xxxxxxxxxxxx2224</PAN><ExpiryDate format=\"yyMM\">1609</ExpiryDate><CardScheme><Description>VISA</Description></CardScheme><ICC type=\"EMV\"><ICCTag tagid=\"0x9F02\">000000000100</ICCTag></ICC></CardDetails></Response>
    )
  end

  def failed_authorize_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>877c147c-b742-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814150556</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814190556</UTC></TransactionDetails><Result><LocalResult>1</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity><Errors><Error code=\"1001\">ExpiredCard</Error></Errors></Result><CardDetails><CardReference>2468f656-9242-e511-ab11-002219649f24</CardReference><CardHash>WSknCJJIvbog334uwCNWUKE9ZbI=</CardHash><PAN>xxxxxxxxxxxx2220</PAN><ExpiryDate format=\"yyMM\">1609</ExpiryDate><CardScheme><Description>VISA</Description></CardScheme></CardDetails></Response>
    )
  end

  def successful_capture_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>607c64ca-b742-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814150811</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814190811</UTC></TransactionDetails><Result><LocalResult>0</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity></Result></Response>
    )
  end

  def failed_capture_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>c4e68fe7-b742-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814150903</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814190903</UTC></TransactionDetails><Result><LocalResult>1</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity><Errors><Error code=\"2101\">CardEaseReferenceInvalid</Error></Errors></Result></Response>
    )
  end

  def successful_refund_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>c8c758b9-b942-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814152200</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814192200</UTC></TransactionDetails><Result><LocalResult>0</LocalResult><AuthCode>AE9111</AuthCode><AuthorisationEntity>Unknown</AuthorisationEntity></Result><CardDetails><CardReference>ed79bf2f-6d3c-e511-ab11-002219649f24</CardReference><CardHash>zLVjUTo7jcI8Z+8hKKd5nqqn4a0=</CardHash><PAN>400010xxxxxx2224</PAN><ExpiryDate format=\"yyMM\">1609</ExpiryDate></CardDetails></Response>
    )
  end

  def failed_refund_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>0732d424-ba42-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814152505</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814192505</UTC></TransactionDetails><Result><LocalResult>1</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity><Errors><Error code=\"2101\">CardEaseReferenceInvalid</Error></Errors></Result></Response>
    )
  end

  def successful_void_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>170c0e63-ba42-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814152646</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814192646</UTC></TransactionDetails><Result><LocalResult>0</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity></Result></Response>
    )
  end

  def failed_void_response
    %(
    <?xml version=\"1.0\" encoding=\"utf-8\"?><Response type=\"CardEaseXML\" version=\"1.0.0\"><TransactionDetails><CardEaseReference>e5b1b672-ba42-e511-b302-00505692354f</CardEaseReference><LocalDateTime format=\"yyyyMMddHHmmss\">20150814152716</LocalDateTime><UTC format=\"yyyyMMddHHmmss\">20150814192716</UTC></TransactionDetails><Result><LocalResult>1</LocalResult><AuthorisationEntity>Unknown</AuthorisationEntity><Errors><Error code=\"2101\">CardEaseReferenceInvalid</Error></Errors></Result></Response>
    )
  end
end
