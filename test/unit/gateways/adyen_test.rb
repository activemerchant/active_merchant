require 'test_helper'

class AdyenTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AdyenGateway.new(
      username: 'ws@adyenmerchant.com',
      password: 'password',
      merchant_account: 'merchantAccount'
    )

    @credit_card = credit_card('4111111111111111',
      :month => 8,
      :year => 2018,
      :first_name => 'Test',
      :last_name => 'Card',
      :verification_value => '737',
      :brand => 'visa'
    )

    @amount = 100

    @options = {
      billing_address: address(),
      order_id: '345123'
    }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '7914775043909934', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Expired Card', response.message
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, '7914775043909934')
    assert_equal '7914775043909934#8814775564188305', response.authorization
    assert_success response
    assert response.test?
  end

def test_successful_capture_with_compount_psp_reference
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, '7914775043909934#8514775559000000')
    assert_equal '7914775043909934#8814775564188305', response.authorization
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(nil, '')
    assert_nil response.authorization
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '7914775043909934#8814775564188305', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, credit_card('400111'), @options)
    assert_failure response

    assert_equal AdyenGateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, '7914775043909934')
    assert_equal '7914775043909934#8514775559925128', response.authorization
    assert_equal '[refund-received]', response.message
    assert response.test?
  end

  def test_successful_refund_with_compound_psp_reference
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, '7914775043909934#8514775559000000')
    assert_equal '7914775043909934#8514775559925128', response.authorization
    assert_equal '[refund-received]', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, '')
    assert_nil response.authorization
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void('7914775043909934')
    assert_equal '7914775043909934#8614775821628806', response.authorization
    assert_equal '[cancel-received]', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('')
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_verify_response)
    assert_success response
    assert_equal '7914776426645103', response.authorization
    assert_equal 'Authorised', response.message
    assert response.test?
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal '7914776433387947', response.authorization
    assert_equal 'Refused', response.message
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_add_address
    post = {:card => {:billingAddress => {}}}
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:address1], post[:card][:billingAddress][:street]
    assert_equal @options[:billing_address][:address2], post[:card][:billingAddress][:houseNumberOrName]
    assert_equal @options[:billing_address][:zip], post[:card][:billingAddress][:postalCode]
    assert_equal @options[:billing_address][:city], post[:card][:billingAddress][:city]
    assert_equal @options[:billing_address][:state], post[:card][:billingAddress][:stateOrProvince]
    assert_equal @options[:billing_address][:country], post[:card][:billingAddress][:country]
  end


  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic d3NfMTYzMjQ1QENvbXBhbnkuRGFuaWVsYmFra2Vybmw6eXU0aD50ZlxIVEdydSU1PDhxYTVMTkxVUw==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"John Smith\",\"number\":\"4111111111111111\",\"cvc\":\"737\"},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: pal-test.adyen.com\r\nContent-Length: 308\r\n\r\n"
      <- "{\"merchantAccount\":\"DanielbakkernlNL\",\"reference\":\"345123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"John Smith\",\"number\":\"[FILTERED]\",\"cvc\":\"[FILTERED]\"},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 27 Oct 2016 11:37:13 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=C0D66C19173B3491D862B8FDBFD72FD7.test3e; Path=/pal/; Secure; HttpOnly\r\n"
      -> "pspReference: 8514775682339577\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8514775682339577\",\"resultCode\":\"Authorised\",\"authCode\":\"31845\"}"
      read 80 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "status": 422,
      "errorCode": "101",
      "message": "Invalid card number",
      "errorType": "validation",
      "pspReference": "8514775645144049"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "pspReference":"7914775043909934",
      "resultCode":"Authorised",
      "authCode":"50055"
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "pspReference": "8514775559925128",
      "refusalReason": "Expired Card",
      "resultCode": "Refused"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "pspReference": "8814775564188305",
      "response": "[capture-received]"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "status": 422,
      "errorCode": "167",
      "message": "Original pspReference required for this operation",
      "errorType": "validation"
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "pspReference": "8514775559925128",
      "response": "[refund-received]"
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "pspReference":"8614775821628806",
      "response":"[cancel-received]"
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    {
      "pspReference":"7914776426645103",
      "resultCode":"Authorised",
      "authCode":"31265"
    }
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
    {
      "pspReference":"7914776433387947",
      "refusalReason":"Refused",
      "resultCode":"Refused"
    }
    RESPONSE
  end
end
