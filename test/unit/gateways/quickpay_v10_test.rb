require 'test_helper'

class QuickpayV10Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = QuickpayV10Gateway.new(:api_key => 'APIKEY')
    @credit_card = credit_card('4242424242424242')
    @amount = 100
    @options = { :order_id => '1', :billing_address => address, :customer_ip => '1.1.1.1' }
  end

  def parse body
    JSON.parse(body)
  end

  def test_unsuccessful_payment
    @gateway.expects(:ssl_post).returns(failed_payment_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.authorization.blank?
    assert_failure response
  end

  def test_successful_purchase
    stub_comms do
      response = @gateway.purchase(@amount, @credit_card, @options)
      assert response
      assert_success response
      assert_equal "1145", response.authorization
      assert response.test?
    end.check_request do |endpoint, data, headers|
      parsed = parse(data)
      if parsed['order_id']
        assert_match %r{/payments}, endpoint
      elsif !parsed['auto_capture'].nil?
        assert_match %r{/payments/\d+/authorize}, endpoint
        assert_equal false, parsed['auto_capture']
      else
        assert_match %r{/payments/\d+/capture}, endpoint
      end
    end.respond_with(successful_payment_response, successful_authorization_response)
  end

  def test_successful_authorization
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_success response
      assert_equal "1145", response.authorization
      assert response.test?
    end.check_request do |endpoint, data, headers|
      parsed_data = parse(data)
      if parsed_data['order_id']
        assert_match %r{/payments}, endpoint
        assert_match "1.1.1.1", @options[:customer_ip]
      else
        assert_match %r{/payments/\d+/authorize}, endpoint
      end
    end.respond_with(successful_payment_response, successful_authorization_response)
  end

  def test_successful_void
    stub_comms do
      assert response = @gateway.void(1145)
      assert_success response
      assert response.test?
    end.check_request do |endpoint, data, headers|
      assert_match %r{/payments/1145/cancel}, endpoint
    end.respond_with({'id' => 1145}.to_json)
  end

  def test_failed_authorization
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_failure response
      assert_equal 'Validation error', response.message
      assert response.test?
    end.respond_with(successful_payment_response, failed_authorization_response)
  end

  def test_parsing_response_with_errors
    stub_comms do
      assert response = @gateway.authorize(@amount, @credit_card, @options)
      assert_failure response
      assert_equal 'is not valid', response.params['errors']['id'][0]
      assert response.test?
    end.respond_with(successful_payment_response, failed_authorization_response)
  end

  def test_successful_store
    stub_comms do
      assert response = @gateway.store(@credit_card, @options)
      assert_success response
      assert response.test?
    end.check_request do |endpoint, data, headers|
      assert_match %r{/card}, endpoint
    end.respond_with(successful_store_response, successful_sauthorize_response)
  end

  def test_successful_unstore
    stub_comms do
      assert response = @gateway.unstore('123')
      assert_success response
      assert response.test?
    end.check_request do |endpoint, data, headers|
      assert_match %r{/cards/\d+/cancel}, endpoint
    end.respond_with({'id' => '123'}.to_json)
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response)
    assert_success response
    assert_equal "OK", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response, {'id' => 1145}.to_json)
    assert_failure response
    assert_equal "Validation error", response.message
  end

  def test_supported_countries
    klass = @gateway.class
    assert_equal ['DE', 'DK', 'ES', 'FI', 'FR', 'FO', 'GB', 'IS', 'NO', 'SE'], klass.supported_countries
  end

  def test_supported_card_types
    klass = @gateway.class
    assert_equal  [:dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ], klass.supported_cardtypes
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(100, 1124)
    assert_success response
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_payment_response
    {
      "id"          =>1145,
      "order_id"    =>"310f59c57a",
      "accepted"    =>false,
      "test_mode"   =>false,
      "branding_id" =>nil,
      "variables"   =>{},
      "acquirer"    =>nil,
      "operations"  =>[],
      "metadata"    =>{},
      "created_at"  =>"2015-03-30T16:56:17Z",
      "balance"     =>0,
      "currency"    =>"DKK"
    }.to_json
  end

  def successful_authorization_response
    {
       "id"          => 1145,
       "order_id"    => "310f59c57a",
       "accepted"    => false,
       "test_mode"   => true,
       "branding_id" => nil,
       "variables"   => {},
       "acquirer"    => "clearhaus",
       "operations"  => [],
       "metadata"    => {
          "type"             =>"card",
          "brand"            =>"quickpay-test-card",
          "last4"            =>"0008",
          "exp_month"        =>9,
          "exp_year"         =>2016,
          "country"          =>"DK",
          "is_3d_secure"     =>false,
          "customer_ip"      =>nil,
          "customer_country" =>nil
       },
      "created_at" => "2015-03-30T16:56:17Z",
      "balance"    => 0,
      "currency"   => "DKK"
    }.to_json
  end

  def successful_capture_response
    {
      "id"          =>1145,
      "order_id"    =>"310f59c57a",
      "accepted"    =>true,
      "test_mode"   =>true,
      "branding_id" =>nil,
      "variables"   =>{},
      "acquirer"    =>"clearhaus",
      "operations"  =>[],
      "metadata"    =>{"type"=>"card", "brand"=>"quickpay-test-card", "last4"=>"0008", "exp_month"=>9, "exp_year"=>2016, "country"=>"DK", "is_3d_secure"=>false, "customer_ip"=>nil, "customer_country"=>nil},
      "created_at"  =>"2015-03-30T16:56:17Z",
      "balance"     =>0,
      "currency"    =>"DKK"
    }.to_json
  end

  def succesful_refund_response
    {
       "id"          =>1145,
       "order_id"    =>"310f59c57a",
       "accepted"    =>true,
       "test_mode"   =>true,
       "branding_id" =>nil,
       "variables"   =>{},
       "acquirer"    =>"clearhaus",
       "operations"  =>[],
       "metadata"=>{
          "type"             =>"card",
          "brand"            =>"quickpay-test-card",
          "last4"            =>"0008",
          "exp_month"        =>9,
          "exp_year"         =>2016,
          "country"          =>"DK",
          "is_3d_secure"     =>false,
          "customer_ip"      =>nil,
          "customer_country" =>nil
        },
        "created_at" =>"2015-03-30T16:56:17Z",
        "balance"    =>100,
        "currency"   =>"DKK"
      }.to_json
  end

  def failed_authorization_response
    {
      'message' => "Validation error",
      "errors" => {
        "id" => ["is not valid"]
      }
    }.to_json
  end

  def failed_payment_response
    {
      "message" => "Validation error",
      "errors" => {
        "currency" => ["must be three uppercase letters"]
      },
      "error_code" => nil
    }.to_json
  end

  def successful_store_response
    {
      'id' => 834,
      'order_id' => '310affr'
    }.to_json
  end

  def successful_sauthorize_response
    {
      'id' => 834,
      'order_id' => '310affr'
    }.to_json
  end

  def expected_expiration_date
    '%02d%02d' % [@credit_card.year.to_s[2..4], @credit_card.month]
  end

  def transcript
    %q(
      POST /payments/7488279/authorize?synchronized HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic OjAzNTA4ZTc3OTFiYTZjOWQwZTY4MzA3MTZlNjUwZjM1YzQzNDJjNGIzNTc2NzIzYWQ1NTZlMjM2Y2E0Yzc3ODg=\r\nUser-Agent: Quickpay-v10 ActiveMerchantBindings/1.52.0\r\nAccept: application/json\r\nAccept-Version: v10\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nConnection: close\r\nHost: api.quickpay.net\r\nContent-Length: 136\r\n\r\n
      {\"amount\":\"100\",\"card\":{\"number\":\"1000000000000008\",\"cvd\":\"123\",\"expiration\":\"1609\",\"issued_to\":\"Longbob Longsen\"},\"auto_capture\":false}
      D, [2015-08-17T11:44:26.710099 #75027] DEBUG -- : {"amount":"100","card":{"number":"1000000000000008","cvd":"123","expiration":"1609","issued_to":"Longbob Longsen"},"auto_capture":false}
    )
  end

  def scrubbed_transcript
    %q(
      POST /payments/7488279/authorize?synchronized HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nUser-Agent: Quickpay-v10 ActiveMerchantBindings/1.52.0\r\nAccept: application/json\r\nAccept-Version: v10\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nConnection: close\r\nHost: api.quickpay.net\r\nContent-Length: 136\r\n\r\n
      {\"amount\":\"100\",\"card\":{\"number\":\"[FILTERED]\",\"cvd\":\"[FILTERED]\",\"expiration\":\"1609\",\"issued_to\":\"Longbob Longsen\"},\"auto_capture\":false}
      D, [2015-08-17T11:44:26.710099 #75027] DEBUG -- : {"amount":"100","card":{"number":"[FILTERED]","cvd":"[FILTERED]","expiration":"1609","issued_to":"Longbob Longsen"},"auto_capture":false}
    )
  end

end
