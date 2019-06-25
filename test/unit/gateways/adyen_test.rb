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

    @elo_credit_card = credit_card('5066 9911 1111 1118',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'elo'
    )

    @three_ds_enrolled_card = credit_card('4212345678901237', brand: :visa)

    @apple_pay_card = network_tokenization_credit_card('4111111111111111',
      :payment_cryptogram => 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      :month              => '08',
      :year               => '2018',
      :source             => :apple_pay,
      :verification_value => nil
    )

    @amount = 100

    @options = {
      billing_address: address(),
      shopper_reference: 'John Smith',
      order_id: '345123',
      installments: 2,
      stored_credential: {reason_type: 'unscheduled'}
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

    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: {reason_type: 'unscheduled'},
      three_ds_2: {
        channel: 'browser',
        browser_info: {
          accept_header: 'unknown',
          depth: 100,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        }
      }
    }
  end

  # Subdomains are only valid for production gateways, so the test_url check must be manually bypassed for this test to pass.
  # def test_subdomain_specification
  #   gateway = AdyenGateway.new(
  #     username: 'ws@adyenmerchant.com',
  #     password: 'password',
  #     merchant_account: 'merchantAccount',
  #     subdomain: '123-subdomain'
  #   )
  #
  #   response = stub_comms(gateway) do
  #     gateway.authorize(@amount, @credit_card, @options)
  #   end.check_request do |endpoint, data, headers|
  #     assert_match("https://123-subdomain-pal-live.adyenpayments.com/pal/servlet/Payment/v18/authorise", endpoint)
  #   end.respond_with(successful_authorize_response)
  #
  #   assert response
  #   assert_success response
  # end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '#7914775043909934#', response.authorization
    assert_equal 'R', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
    assert response.test?
  end

  def test_successful_authorize_with_3ds
    @gateway.expects(:ssl_post).returns(successful_authorize_with_3ds_response)

    response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal '#8835440446784145#', response.authorization
    assert_equal response.params['resultCode'], 'RedirectShopper'
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
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
    assert_equal '7914775043909934#8814775564188305#', response.authorization
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
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_elo_card
    response = stub_comms do
      @gateway.purchase(@amount, @elo_credit_card, @options)
    end.respond_with(successful_authorize_with_elo_response, successful_capture_with_elo_repsonse)
    assert_success response
    assert_equal '8835511210681145#8835511210689965#', response.authorization
    assert response.test?
  end

  def test_successful_maestro_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({selected_brand: 'maestro', overwrite_brand: 'true'}))
    end.check_request do |endpoint, data, headers|
      if endpoint =~ /authorise/
        assert_match(/"overwriteBrand":true/, data)
        assert_match(/"selectedBrand":"maestro"/, data)
      end
    end.respond_with(successful_authorize_response, successful_capture_response)
    assert_success response
    assert_equal '7914775043909934#8814775564188305#', response.authorization
    assert response.test?
  end

  def test_3ds_2_fields_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @normalized_3ds_2_options)
    end.check_request do |endpoint, data, headers|
      data = JSON.parse(data)
      assert_equal 'browser', data['threeDS2RequestData']['deviceChannel']
      assert_equal 'unknown', data['browserInfo']['acceptHeader']
      assert_equal 100, data['browserInfo']['colorDepth']
      assert_equal false, data['browserInfo']['javaEnabled']
      assert_equal 'US', data['browserInfo']['language']
      assert_equal 1000, data['browserInfo']['screenHeight']
      assert_equal 500, data['browserInfo']['screenWidth']
      assert_equal '-120', data['browserInfo']['timeZoneOffset']
      assert_equal 'unknown', data['browserInfo']['userAgent']
    end.respond_with(successful_authorize_response)
  end

  def test_installments_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal 2, JSON.parse(data)['installments']['value']
    end.respond_with(successful_authorize_response)
  end

  def test_custom_routing_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({custom_routing_flag: 'abcdefg'}))
    end.check_request do |endpoint, data, headers|
      assert_equal 'abcdefg', JSON.parse(data)['additionalData']['customRoutingFlag']
    end.respond_with(successful_authorize_response)
  end

  def test_update_shopper_statement_and_industry_usage_sent
    stub_comms do
      @gateway.adjust(@amount, '123', @options.merge({update_shopper_statement: 'statement note', industry_usage: 'DelayedCharge'}))
    end.check_request do |endpoint, data, headers|
      assert_equal 'statement note', JSON.parse(data)['additionalData']['updateShopperStatement']
      assert_equal 'DelayedCharge', JSON.parse(data)['additionalData']['industryUsage']
    end.respond_with(successful_adjust_response)
  end

  def test_risk_data_sent
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge({risk_data: {'operatingSystem' => 'HAL9000'}}))
    end.check_request do |endpoint, data, headers|
      assert_equal 'HAL9000', JSON.parse(data)['additionalData']['riskdata.operatingSystem']
    end.respond_with(successful_authorize_response)
  end

  def test_risk_data_complex_data
    stub_comms do
      risk_data = {
        'deliveryMethod' => 'express',
        'basket.item.productTitle' => 'Blue T Shirt',
        'promotions.promotion.promotionName' => 'Big Sale promotion'
      }
      @gateway.authorize(@amount, @credit_card, @options.merge({risk_data: risk_data}))
    end.check_request do |endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal 'express', parsed['additionalData']['riskdata.deliveryMethod']
      assert_equal 'Blue T Shirt', parsed['additionalData']['riskdata.basket.item.productTitle']
      assert_equal 'Big Sale promotion', parsed['additionalData']['riskdata.promotions.promotion.promotionName']
    end.respond_with(successful_authorize_response)
  end

  def test_successful_authorize_with_normalized_stored_credentials
    @credit_card.verification_value = nil
    stub_comms do
      @gateway.authorize(50, @credit_card, @options.merge(@normalized_stored_credential))
    end.check_request do |endpoint, data, headers|
      assert_match(/"shopperInteraction":"ContAuth"/, data)
      assert_match(/"recurringProcessingModel":"Subscription"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_successful_initial_authorize_with_normalized_stored_credentials
    stub_comms do
      @gateway.authorize(50, @credit_card, @options.merge(@normalized_initial_stored_credential))
    end.check_request do |endpoint, data, headers|
      assert_match(/"shopperInteraction":"Ecommerce"/, data)
      assert_match(/"recurringProcessingModel":"CardOnFile"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_nonfractional_currency_handling_with_amount_modification
    stub_comms do
      @gateway.authorize(1, @credit_card, @options.merge(currency: 'JPY'))
    end.check_request do |endpoint, data, headers|
      assert_match(/"amount\":{\"value\":\"1\",\"currency\":\"JPY\"}/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_nonfractional_currency_handling_without_amount_modification
    stub_comms do
      @gateway.authorize(200, @credit_card, @options.merge(currency: 'JPY', opt_out_multiply_amount: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/"amount\":{\"value\":\"2\",\"currency\":\"JPY\"}/, data)
    end.respond_with(successful_authorize_response)

    stub_comms do
      @gateway.authorize(200, @credit_card, @options.merge(currency: 'CLP'))
    end.check_request do |endpoint, data, headers|
      assert_match(/"amount\":{\"value\":\"200\",\"currency\":\"CLP\"}/, data)
    end.respond_with(successful_authorize_response)
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
    assert_equal '7914775043909934#8514775559925128#', response.authorization
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
    assert_equal '7914775043909934#8614775821628806#', response.authorization
    assert_equal '[cancel-received]', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('')
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_adjust
    @gateway.expects(:ssl_post).returns(successful_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal '8835544088660594#8835544088660594#', response.authorization
    assert_equal '[adjustAuthorisation-received]', response.message
  end

  def test_failed_adjust
    @gateway.expects(:ssl_post).returns(failed_adjust_response)
    response = @gateway.adjust(200, '')
    assert_equal 'Original pspReference required for this operation', response.message
    assert_failure response
  end

  def test_successful_synchronous_adjust
    @gateway.expects(:ssl_post).returns(successful_synchronous_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal '8835544088660594#8835574118820108#', response.authorization
    assert_equal 'Authorised', response.message
  end

  def test_failed_synchronous_adjust
    @gateway.expects(:ssl_post).returns(failed_synchronous_adjust_response)
    response = @gateway.adjust(200, '8835544088660594')
    assert_equal 'Refused', response.message
    assert_failure response
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal 'CardOnFile', JSON.parse(data)['recurringProcessingModel']
    end.respond_with(successful_store_response)
    assert_success response
    assert_equal '#8835205392522157#8315202663743702', response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_verify_response)
    assert_success response
    assert_equal '#7914776426645103#', response.authorization
    assert_equal 'Authorised', response.message
    assert response.test?
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal '#7914776433387947#', response.authorization
    assert_equal 'Refused', response.message
    assert response.test?
  end

  def test_failed_avs_check_returns_refusal_reason_raw
    @gateway.expects(:ssl_post).returns(failed_authorize_avs_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Refused | 05 : Do not honor', response.message
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
    post = {:card => {:billingAddress => {}}}
    @options[:billing_address].delete(:address1)
    @options[:billing_address].delete(:address2)
    @options[:billing_address].delete(:state)
    @gateway.send(:add_address, post, @options)
    assert_equal 'N/A', post[:billingAddress][:street]
    assert_equal 'N/A', post[:billingAddress][:houseNumberOrName]
    assert_equal 'N/A', post[:billingAddress][:stateOrProvince]
    assert_equal @options[:billing_address][:zip], post[:billingAddress][:postalCode]
    assert_equal @options[:billing_address][:city], post[:billingAddress][:city]
    assert_equal @options[:billing_address][:country], post[:billingAddress][:country]
  end

  def test_authorize_with_network_tokenization_credit_card_no_name
    @apple_pay_card.first_name = nil
    @apple_pay_card.last_name = nil
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_equal 'Not Provided', JSON.parse(data)['card']['holderName']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_authorize_with_network_tokenization_credit_card
    response = stub_comms do
      @gateway.authorize(@amount, @apple_pay_card, @options)
    end.check_request do |endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal 'YwAAAAAABaYcCMX/OhNRQAAAAAA=', parsed['mpiData']['cavv']
      assert_equal '07', parsed['mpiData']['eci']
      assert_equal 'applepay', parsed['additionalData']['paymentdatasource.type']
    end.respond_with(successful_authorize_response)
    assert_success response
  end

  def test_extended_avs_response
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(extended_avs_response)
    assert_equal 'Card member\'s name, billing address, and billing postal code match.', response.avs_result['message']
  end

  def test_optional_idempotency_key_header
    options = @options.merge(:idempotency_key => 'test123')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert headers['Idempotency-Key']
    end.respond_with(successful_authorize_response)
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

  def successful_authorize_with_elo_response
    <<-RESPONSE
    {
      "pspReference":"8835511210681145",
      "resultCode":"Authorised",
      "authCode":"98696"
    }
    RESPONSE
  end

  def successful_capture_with_elo_repsonse
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

  def successful_authorize_with_3ds_response
    '{"pspReference":"8835440446784145","resultCode":"RedirectShopper","issuerUrl":"https:\\/\\/test.adyen.com\\/hpp\\/3d\\/validate.shtml","md":"djIhcWk3MUhlVFlyQ1h2UC9NWmhpVm10Zz09IfIxi5eDMZgG72AUXy7PEU86esY68wr2cunaFo5VRyNPuWg3ZSvEIFuielSuoYol5WhjCH+R6EJTjVqY8eCTt+0wiqHd5btd82NstIc8idJuvg5OCu2j8dYo0Pg7nYxW\\/2vXV9Wy\\/RYvwR8tFfyZVC\\/U2028JuWtP2WxrBTqJ6nV2mDoX2chqMRSmX8xrL6VgiLoEfzCC\\/c+14r77+whHP0Mz96IGFf4BIA2Qo8wi2vrTlccH\\/zkLb5hevvV6QH3s9h0\\/JibcUrpoXH6M903ulGuikTr8oqVjEB9w8\\/WlUuxukHmqqXqAeOPA6gScehs6SpRm45PLpLysCfUricEIDhpPN1QCjjgw8+qVf3Ja1SzwfjCVocU","paRequest":"eNpVUctuwjAQ\\/BXaD2Dt4JCHFkspqVQOBChwriJnBanIAyepoF9fG5LS+jQz612PZ3F31ETxllSnSeKSmiY90CjPZs+h709cIZgQU88XXLjPEtfRO50lfpFu8qqUfMzGDsJATbtWx7RsJabq\\/LJIJHcmwp0i9BQL0otY7qhp10URqXOXa9IIdxnLtCC5jz6i+VO4rY2v7HSdr5ZOIBBuNVRVV7b6Kn3BEAaCnT7JY9vWIUDTt41VVSDYAsLD1bqzqDGDLnkmV\\/HhO9lt2DLesORTiSR+ZckmsmeGYG9glrYkHcZ97jB35PCQe6HrI9x0TAvrQO638cgkYRz1Atb2nehOuC38FdBEralUwy8GhnSpq5LMDRPpL0Z4mJ6\\/2WBVa7ISzj1azw+YQZ6N+FawU3ITCg9YcBtjCYJthX570G\\/ZoH\\/b\\/wFlSqpp"}'
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

  def successful_adjust_response
    <<-RESPONSE
    {
      "pspReference": "8835544088660594",
      "response": "[adjustAuthorisation-received]"
    }
    RESPONSE
  end

  def failed_adjust_response
    <<-RESPONSE
    {
      "status":422,
      "errorCode":"167",
      "message":"Original pspReference required for this operation",
      "errorType":"validation"
    }
    RESPONSE
  end

  def successful_synchronous_adjust_response
    <<-RESPONSE
    {\"additionalData\":{\"authCode\":\"70125\",\"adjustAuthorisationData\":\"BQABAQA9NtGnJAkLXKqW1C+VUeCNMzDf4WwzLFBiuQ8iaA2Yvflz41t0cYxtA7XVzG2pzlJPMnkSK75k3eByNS0\\/m0\\/N2+NnnKv\\/9rYPn8Pjq1jc7CapczdqZNl8P9FwqtIa4Kdeq7ZBNeGalx9oH4reutlFggzWCr+4eYXMRqMgQNI2Bu5XvwkqBbXwbDL05CuNPjjEwO64YrCpVBLrxk4vlW4fvCLFR0u8O68C+Y4swmsPDvGUxWpRgwNVqXsTmvt9z8hlej21BErL8fPEy+fJP4Zab8oyfcLrv9FJkHZq03cyzJpOzqX458Ctn9sIwBawXzNEFN5bCt6eT1rgp0yuHeMGEGwrjNl8rijez7Rd\\/vy1WUYAAMfmZFuJMQ73l1+Hkr0VlHv6crlyP\\/FVTY\\/XIUiGMqa1yM08Zu\\/Gur5N7lU8qnMi2WO9QPyHmmdlfo7+AGsrKrzV4wY\\/wISg0pcv8PypBWVq\\/hYoCqlHsGUuIiyGLIW7A8LtG6\\/JqAA9t\\/0EdnQVz0k06IEEYnBzkQoY8Qv3cVszgPQukGstBraB47gQdVDp9vmuQjMstt8Te56SDRxtfcu0z4nQIURVSkJJNj8RYfwXH9OUbz3Vd2vwoR3lCJFTCKIeW8sidNVB3xAZnddBVQ3P\\/QxPnrrRdCcnoWSGoEOBBIxgF00XwNxJ4P7Xj1bB7oq3M7k99dgPnSdZIjyvG6BWKnCQcGyVRB0yOaYBaOCmN66EgWfXoJR5BA4Jo6gnWnESWV62iUC8OCzmis1VagfaBn0A9vWNcqKFkUr\\/68s3w8ixLJFy+WdpAS\\/flzC3bJbvy9YR9nESKAP40XiNGz9iBROCfPI2bSOvdFf831RdTxWaE+ewAC3w9GsgEKAXxzWsVeSODWRZQA0TEVOfX8SaNVa5w3EXLDsRVnmKgUH8yQnEJQBGhDJXg1sEbowE07CzzdAY5Mc=\",\"refusalReasonRaw\":\"AUTHORISED\"},\"pspReference\":\"8835574118820108\",\"response\":\"Authorised\"}
    RESPONSE
  end

  def failed_synchronous_adjust_response
    <<-RESPONSE
    {\"additionalData\":{\"authCode\":\"90745\",\"refusalReasonRaw\":\"2\"},\"pspReference\":\"8835574120337117\",\"response\":\"Refused\"}
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

  def failed_authorize_avs_response
    <<-RESPONSE
    {\"additionalData\":{\"cvcResult\":\"0 Unknown\",\"fraudResultType\":\"GREEN\",\"avsResult\":\"3 AVS unavailable\",\"fraudManualReview\":\"false\",\"avsResultRaw\":\"U\",\"refusalReasonRaw\":\"05 : Do not honor\",\"authorisationMid\":\"494619000001174\",\"acquirerCode\":\"AdyenVisa_BR_494619\",\"acquirerReference\":\"802320302458\",\"acquirerAccountCode\":\"AdyenVisa_BR_Cabify\"},\"fraudResult\":{\"accountScore\":0,\"results\":[{\"FraudCheckResult\":{\"accountScore\":0,\"checkId\":46,\"name\":\"DistinctCountryUsageByShopper\"}}]},\"pspReference\":\"1715167376763498\",\"refusalReason\":\"Refused\",\"resultCode\":\"Refused\"}
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

  def extended_avs_response
    <<-RESPONSE
    {\"additionalData\":{\"cvcResult\":\"1 Matches\",\"cvcResultRaw\":\"Y\",\"avsResult\":\"20 Name, address and zip match\",\"avsResultRaw\":\"M\"}}
    RESPONSE
  end
end
