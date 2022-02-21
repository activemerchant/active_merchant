require 'test_helper'

class AdyenTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AdyenCheckoutGateway.new(
        username: 'ws@adyenmerchant.com',
        password: 'password',
        merchant_account: 'merchantAccount',
        url_prefix: 'random-account'
    )

    @credit_card = credit_card('4111111111111111',
        :month => 8,
        :year => 2018,
        :first_name => 'Test',
        :last_name => 'Card',
        :verification_value => '737',
        :brand => 'visa'
    )

    @elo_credit_card = credit_card('5066 9911 1111 1118',
        :month => 10,
        :year => 2020,
        :first_name => 'John',
        :last_name => 'Smith',
        :verification_value => '737',
        :brand => 'elo'
    )

    @unionpay_credit_card = credit_card('8171 9999 0000 0000 021',
        :month => 10,
        :year => 2030,
        :first_name => 'John',
        :last_name => 'Smith',
        :verification_value => '737',
        :brand => 'unionpay'
    )

    @amount = 100

    @options = {
        billing_address: address(),
        shipping_address: address(),
        shopper_reference: 'John Smith',
        order_id: '345123',
        installments: 2
    }

    @normalized_initial_stored_credential = {
        stored_credential: {
            initial_transaction: true,
            reason_type: 'unscheduled'
        }
    }

    @normalized_stored_credential = {
        stored_credential: {
            initial_transaction: false,
            reason_type: 'recurring'
        }
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(recurring_processing_model: 'Subscription'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'Subscription', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '#7914775043909934#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_elo_card
    response = stub_comms do
      @gateway.purchase(@amount, @elo_credit_card, @options)
    end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
    assert_success response
    assert_equal '#8835511210681145#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_unionpay_card
    response = stub_comms do
      @gateway.purchase(@amount, @unionpay_credit_card, @options)
    end.respond_with(simple_successful_authorize_response, simple_successful_capture_repsonse)
    assert_success response
    assert_equal '#8835511210681145#', response.authorization
    assert response.test?
  end

  def test_successful_maestro_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({selected_brand: 'maestro', overwrite_brand: 'true'}))
    end.check_request do |endpoint, data, _headers|
      if endpoint =~ /authorise/
        assert_match(/"overwriteBrand":true/, data)
        assert_match(/"selectedBrand":"maestro"/, data)
      end
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '#7914775043909934#', response.authorization
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
    assert_equal '7914775043909934#8514775559925128#', response.authorization
    assert_equal '[refund-received]', response.message
    assert response.test?
  end

  def test_successful_refund_with_compound_psp_reference
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, '7914775043909934#8514775559000000')
    assert_equal '8514775559000000#8514775559925128#', response.authorization
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

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge(recurring_processing_model: 'Subscription'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'Subscription', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_successful_update_card_details_store
    response = stub_comms do
      @gateway.update(
        @credit_card,
        @options.merge(
          stored_payment_method_id: "8415877192784258",
          recurring_processing_model: 'Subscription')
        )
    end.check_request do |_endpoint, data, _headers|
      assert_equal payment_method_for_update_card_details, JSON.parse(data)['paymentMethod']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_successful_store_with_add_3ds_data
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge(allow3DS2: true, origin: 'http://localhost', channel: 'web', browser_info: {}))
    end.check_request do |_endpoint, data, _headers|
      assert_equal true, JSON.parse(data)['additionalData']['allow3DS2']
      assert_equal 'web', JSON.parse(data)['channel']
      assert_equal 'http://localhost', JSON.parse(data)['origin']
      assert_equal Hash.new, JSON.parse(data)['browserInfo']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_successful_store_with_three_ds_data
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge(three_ds_data: { paymentData: 'fake', details: 'fake' }))
    end.check_request do |endpoint, data, _headers|
      r = { "paymentData" => nil, "details" => nil }
      assert_equal r, JSON.parse(data)
      assert_equal "https://checkout-test.adyen.com/v51/payments/details", endpoint
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'Refused | Refused', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_scrub_network_tokenization_card
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_add_address
    post = {:paymentMethod => {:billingAddress => {}}}
    @options[:billing_address].delete(:address1)
    @options[:billing_address].delete(:address2)
    @options[:billing_address].delete(:state)
    @options[:shipping_address].delete(:state)
    @gateway.send(:add_address, post, @options)
    # Billing Address
    assert_equal 'NA', post[:billingAddress][:street]
    assert_equal 'NA', post[:billingAddress][:houseNumberOrName]
    assert_equal 'NA', post[:billingAddress][:stateOrProvince]
    assert_equal @options[:billing_address][:zip], post[:billingAddress][:postalCode]
    assert_equal @options[:billing_address][:city], post[:billingAddress][:city]
    assert_equal @options[:billing_address][:country], post[:billingAddress][:country]
    # Shipping Address
    assert_equal 'NA', post[:deliveryAddress][:stateOrProvince]
    assert_equal @options[:shipping_address][:address1], post[:deliveryAddress][:street]
    assert_equal @options[:shipping_address][:address2], post[:deliveryAddress][:houseNumberOrName]
    assert_equal @options[:shipping_address][:zip], post[:deliveryAddress][:postalCode]
    assert_equal @options[:shipping_address][:city], post[:deliveryAddress][:city]
    assert_equal @options[:shipping_address][:country], post[:deliveryAddress][:country]
  end

  def test_unstore
    response = stub_comms do
      @gateway.unstore(unstore_token, {})
    end.check_request do |_endpoint, data, _headers|
      assert_equal unstore_data, JSON.parse(data)
    end.respond_with(successful_unstore_response)
    assert_success response
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

  def pre_scrubbed_network_tokenization_card
    <<-PRE_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      I, [2018-06-18T11:53:47.394267 #25363]  INFO -- : [ActiveMerchant::Billing::AdyenGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
      D, [2018-06-18T11:53:47.394346 #25363] DEBUG -- : {"merchantAccount":"SpreedlyCOM294","reference":"123","amount":{"value":"100","currency":"USD"},"mpiData":{"authenticationResponse":"Y","cavv":"YwAAAAAABaYcCMX/OhNRQAAAAAA=","directoryResponse":"Y","eci":"07"},"card":{"expiryMonth":8,"expiryYear":2018,"holderName":"Longbob Longsen","number":"4111111111111111","billingAddress":{"street":"456 My Street","houseNumberOrName":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","stateOrProvince":"ON","country":"CA"}},"shopperEmail":"john.smith@test.com","shopperIP":"77.110.174.153","shopperReference":"John Smith","selectedBrand":"applepay","shopperInteraction":"Ecommerce"}
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic d3NAQ29tcGFueS5TcHJlZWRseTQ3MTo3c3d6U0p2R1VWViUvP3Q0Uy9bOVtoc0hF\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: pal-test.adyen.com\r\nContent-Length: 618\r\n\r\n"
      <- "{\"merchantAccount\":\"SpreedlyCOM294\",\"reference\":\"123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"mpiData\":{\"authenticationResponse\":\"Y\",\"cavv\":\"YwAAAAAABaYcCMX/OhNRQAAAAAA=\",\"directoryResponse\":\"Y\",\"eci\":\"07\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"Longbob Longsen\",\"number\":\"4111111111111111\",\"billingAddress\":{\"street\":\"456 My Street\",\"houseNumberOrName\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"stateOrProvince\":\"ON\",\"country\":\"CA\"}},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\",\"selectedBrand\":\"applepay\",\"shopperInteraction\":\"Ecommerce\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 18 Jun 2018 15:53:47 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=06EE78291B761A33ED9E21E46BA54649.test104e; Path=/pal; Secure; HttpOnly\r\n"
      -> "pspReference: 8835293372276408\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8835293372276408\",\"resultCode\":\"Authorised\",\"authCode\":\"26056\"}"
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

  def post_scrubbed_network_tokenization_card
    <<-POST_SCRUBBED
      opening connection to pal-test.adyen.com:443...
      opened
      starting SSL for pal-test.adyen.com:443...
      SSL established
      I, [2018-06-18T11:53:47.394267 #25363]  INFO -- : [ActiveMerchant::Billing::AdyenGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
      D, [2018-06-18T11:53:47.394346 #25363] DEBUG -- : {"merchantAccount":"SpreedlyCOM294","reference":"123","amount":{"value":"100","currency":"USD"},"mpiData":{"authenticationResponse":"Y","cavv":"[FILTERED]","directoryResponse":"Y","eci":"07"},"card":{"expiryMonth":8,"expiryYear":2018,"holderName":"Longbob Longsen","number":"[FILTERED]","billingAddress":{"street":"456 My Street","houseNumberOrName":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","stateOrProvince":"ON","country":"CA"}},"shopperEmail":"john.smith@test.com","shopperIP":"77.110.174.153","shopperReference":"John Smith","selectedBrand":"applepay","shopperInteraction":"Ecommerce"}
      <- "POST /pal/servlet/Payment/v18/authorise HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: pal-test.adyen.com\r\nContent-Length: 618\r\n\r\n"
      <- "{\"merchantAccount\":\"SpreedlyCOM294\",\"reference\":\"123\",\"amount\":{\"value\":\"100\",\"currency\":\"USD\"},\"mpiData\":{\"authenticationResponse\":\"Y\",\"cavv\":\"[FILTERED]\",\"directoryResponse\":\"Y\",\"eci\":\"07\"},\"card\":{\"expiryMonth\":8,\"expiryYear\":2018,\"holderName\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"billingAddress\":{\"street\":\"456 My Street\",\"houseNumberOrName\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"stateOrProvince\":\"ON\",\"country\":\"CA\"}},\"shopperEmail\":\"john.smith@test.com\",\"shopperIP\":\"77.110.174.153\",\"shopperReference\":\"John Smith\",\"selectedBrand\":\"applepay\",\"shopperInteraction\":\"Ecommerce\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Mon, 18 Jun 2018 15:53:47 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Set-Cookie: JSESSIONID=06EE78291B761A33ED9E21E46BA54649.test104e; Path=/pal; Secure; HttpOnly\r\n"
      -> "pspReference: 8835293372276408\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "\r\n"
      -> "50\r\n"
      reading 80 bytes...
      -> ""
      -> "{\"pspReference\":\"8835293372276408\",\"resultCode\":\"Authorised\",\"authCode\":\"26056\"}"
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

  def simple_successful_authorize_response
    <<-RESPONSE
    {
      "pspReference":"8835511210681145",
      "resultCode":"Authorised",
      "authCode":"98696"
    }
    RESPONSE
  end

  def simple_successful_capture_repsonse
    <<-RESPONSE
    {
      "pspReference":"8835511210689965",
      "response":"[capture-received]"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "additionalData": {
        "cvcResult": "1 Matches",
        "avsResult": "0 Unknown",
        "cvcResultRaw": "M"
      },
      "pspReference":"7914775043909934",
      "resultCode":"Authorised",
      "authCode":"50055"
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

  def successful_store_response
    <<-RESPONSE
    {"additionalData":{"recurring.recurringDetailReference":"8315202663743702","recurring.shopperReference":"John Smith"},"pspReference":"8835205392522157","resultCode":"Authorised","authCode":"94571"}
    RESPONSE
  end

  def failed_store_response
    <<-RESPONSE
    {"pspReference":"8835205393394754","refusalReason":"Refused","resultCode":"Refused"}
    RESPONSE
  end

  def payment_method_for_update_card_details
    {
      "expiryMonth" => 8,
      "expiryYear" => 2018,
      "holderName" => "Test Card",
      "storedPaymentMethodId" => "8415877192784258"
    }
  end

  def unstore_token
    @unstore_token ||= mock.tap do |mock_token|
      mock_token.expects(:[], :payment_profile_token).returns("120731391")
      mock_token.expects(:[], :customer_profile_token).returns("chargify_5")
      mock_token.expects(:[], :merchant_account).returns(nil)
      mock_token.expects(:[], :order_id).returns(nil)
    end
  end

  def unstore_data
    {
      "merchantAccount" => "merchantAccount",
      "shopperReference" => "chargify_5",
      "recurringDetailReference" => "120731391"
    }
  end

  def successful_unstore_response
    <<-RESPONSE
    {
      "response": "[detail-successfully-disabled]"
    }
    RESPONSE
  end
end
