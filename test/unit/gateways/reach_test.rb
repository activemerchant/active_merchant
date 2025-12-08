require 'test_helper'

class ReachTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ReachGateway.new(fixtures(:reach))
    @credit_card = credit_card
    @amount = 100

    @options = {
      email: 'johndoe@reach.com',
      order_id: '123',
      currency: 'USD',
      billing_address: {
        address1: '1670',
        address2: '1670 NW 82ND AVE',
        city: 'Miami',
        state: 'FL',
        zip: '32191',
        country: 'US'
      }
    }
  end

  def test_api_version
    assert_equal 'v2.22', @gateway.fetch_version
  end

  def test_required_merchant_id_and_secret
    error = assert_raises(ArgumentError) { ReachGateway.new }
    assert_equal 'Missing required parameter: merchant_id', error.message
  end

  def test_supported_card_types
    assert_equal ReachGateway.supported_cardtypes, %i[visa diners_club american_express jcb master discover maestro]
  end

  def test_should_be_able_format_a_request
    post = {
      request: { someId: 'abc123' },
      card: { number: '12132323', name: 'John doe' }
    }

    formatted = @gateway.send :format_and_sign, post

    refute_empty formatted[:signature]
    assert_kind_of String, formatted[:request]
    assert_kind_of String, formatted[:card]

    assert_equal 'abc123', JSON.parse(formatted[:request])['someId']
    assert_equal '12132323', JSON.parse(formatted[:card])['number']
    assert formatted[:signature].present?
  end

  def test_properly_format_on_zero_decilmal
    @options[:currency] = 'BYR'
    stub_comms do
      @gateway.authorize(1000, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal '10', request['Items'].first['ConsumerPrice']
    end.respond_with(successful_purchase_response)
  end

  def test_successfully_build_a_purchase
    stub_comms do
      @gateway.authorize(1250, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      card = JSON.parse(URI.decode_www_form(data)[1][1])

      # request
      assert_equal request['ReferenceId'], @options[:order_id]
      assert_equal request['Consumer']['Email'], @options[:email]
      assert_equal request['ConsumerCurrency'], @options[:currency]
      assert_equal request['Capture'], false
      assert_equal '12.50', request['Items'].first['ConsumerPrice']

      # card
      assert_equal card['Number'], @credit_card.number
      assert_equal card['Name'], @credit_card.name
      assert_equal card['VerificationCode'], @credit_card.verification_value
    end.respond_with(successful_purchase_response)
  end

  def test_successfully_build_a_purchase_with_fingerprint
    stub_comms do
      @options[:device_fingerprint] = '54fd66c2-b5b5-4dbd-ab89-12a8b6177347'
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal request['DeviceFingerprint'], @options[:device_fingerprint]
    end.respond_with(successful_purchase_response)
  end

  def test_properly_set_capture_flag_on_purchase
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal true, request['Capture']
    end.respond_with(successful_purchase_response)
  end

  def test_sending_item_sku_and_item_price
    @options[:item_sku] = '1212121212'
    @options[:item_quantity] = 250

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])

      # request
      assert_equal request['Items'].first['Sku'], @options[:item_sku]
      assert_equal request['Items'].first['Quantity'], @options[:item_quantity]
    end.respond_with(successful_purchase_response)
  end

  def test_successfull_retrieve_error_message
    response = { 'response' => { 'Error' => { 'ReasonCode' => 'is an error' } } }

    message = @gateway.send(:message_from, response)
    assert_equal 'is an error', message
  end

  def test_safe_retrieve_error_message
    response = { 'response' => { 'Error' => { 'Code' => 'is an error' } } }

    message = @gateway.send(:message_from, response)
    assert_nil message
  end

  def test_sucess_from_on_sucess_result
    response = { 'response' => { OrderId: '' } }

    assert @gateway.send(:success_from, response)
  end

  def test_sucess_from_on_failure
    response = { 'response' => { 'Error' => 'is an error' } }

    refute @gateway.send(:success_from, response)
  end

  def test_stored_credential
    cases =
      [
        { { initial_transaction: true, initiator: 'cardholder', reason_type: 'installment' } => 'CIT-Setup-Scheduled' },
        { { initial_transaction: true, initiator: 'cardholder', reason_type: 'unscheduled' } => 'CIT-Setup-Unscheduled-MIT' },
        { { initial_transaction: true, initiator: 'cardholder', reason_type: 'recurring' } => 'CIT-Setup-Unscheduled' },
        { { initial_transaction: false, initiator: 'cardholder', reason_type: 'unscheduled' } => 'CIT-Subsequent-Unscheduled' },
        { { initial_transaction: false, initiator: 'merchant', reason_type: 'recurring' } => 'MIT-Subsequent-Scheduled' },
        { { initial_transaction: false, initiator: 'merchant', reason_type: 'unscheduled' } => 'MIT-Subsequent-Unscheduled' }
      ]

    cases.each do |stored_credential_case|
      stored_credential_options = stored_credential_case.keys[0]
      expected = stored_credential_case[stored_credential_options]
      @options[:stored_credential] = stored_credential_options
      stub_comms do
        @gateway.expects(:ssl_request).returns(succesful_query_response)
        @gateway.purchase(@amount, @credit_card, @options)
      end.check_request do |_endpoint, data, _headers|
        request = JSON.parse(URI.decode_www_form(data)[0][1])
        assert_equal expected, request['PaymentModel']
      end.respond_with(successful_purchase_response)
    end
  end

  def test_stored_credential_with_no_store_credential_parameters
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_equal 'CIT-One-Time', request['PaymentModel']
    end.respond_with(successful_purchase_response)
  end

  def test_stored_credential_with_wrong_combination_stored_credential_paramaters
    @options[:stored_credential] = { initiator: 'merchant', initial_transaction: true, reason_type: 'unscheduled' }
    @gateway.expects(:get_network_payment_reference).returns(stub(message: 'abc123', success?: true))

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_empty request['PaymentModel']
    end.respond_with(successful_purchase_response)
  end

  def test_stored_credential_with_at_lest_one_stored_credential_paramaters_nil
    @options[:stored_credential] = { initiator: 'merchant', initial_transaction: true, reason_type: nil }
    @gateway.expects(:get_network_payment_reference).returns(stub(message: 'abc123', success?: true))

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(URI.decode_www_form(data)[0][1])
      assert_empty request['PaymentModel']
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?

    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_purchase_response
    'response=%7B%22OrderId%22%3A%22e8f8c529-15c7-46c1-b28b-9d43bb5efe92%22%2C%22UnderReview%22%3Afalse%2C%22Expiry%22%3A%222022-11-03T12%3A47%3A21Z%22%2C%22Authorized%22%3Atrue%2C%22Completed%22%3Afalse%2C%22Captured%22%3Afalse%7D&signature=JqLa7Y68OYRgRcA5ALHOZwXXzdZFeNzqHma2RT2JWAg%3D'
  end

  def succesful_query_response
    'response=%7B%22Meta%22%3A%20null%2C%20%22Rate%22%3A%201.000000000000%2C%20%22Items%22%3A%20%5B%7B%22Sku%22%3A%20%22RLaP7OsSZjbR2pJK%22%2C%20%22Quantity%22%3A%201%2C%20%22ConsumerPrice%22%3A%20100.00%2C%20%22MerchantPrice%22%3A%20100.00%7D%5D%2C%20%22Store%22%3A%20null%2C%20%22Times%22%3A%20%7B%22Created%22%3A%20%222022-12-05T17%3A48%3A18.830991Z%22%2C%20%22Processed%22%3A%20null%2C%20%22Authorized%22%3A%20%222022-12-05T17%3A48%3A19.855608Z%22%7D%2C%20%22Action%22%3A%20null%2C%20%22Expiry%22%3A%20%222022-12-12T17%3A48%3A19.855608Z%22%2C%20%22Reason%22%3A%20null%2C%20%22Charges%22%3A%20null%2C%20%22OrderId%22%3A%20%226ec68268-a4a5-44dd-8997-e76df4aa9c97%22%2C%20%22Payment%22%3A%20%7B%22Class%22%3A%20%22Card%22%2C%20%22Expiry%22%3A%20%222030-03%22%2C%20%22Method%22%3A%20%22VISA%22%2C%20%22AccountIdentifier%22%3A%20%22444433******1111%22%2C%20%22NetworkPaymentReference%22%3A%20%22546646904394415%22%7D%2C%20%22Refunds%22%3A%20%5B%5D%2C%20%22Consumer%22%3A%20%7B%22City%22%3A%20%22Miami%22%2C%20%22Name%22%3A%20%22Longbob%20Longsen%22%2C%20%22Email%22%3A%20%22johndoe%40reach.com%22%2C%20%22Address%22%3A%20%221670%22%2C%20%22Country%22%3A%20%22US%22%2C%20%22EffectiveIpAddress%22%3A%20%22181.78.14.203%22%7D%2C%20%22Shipping%22%3A%20null%2C%20%22Consignee%22%3A%20null%2C%20%22Discounts%22%3A%20null%2C%20%22Financing%22%3A%20null%2C%20%22Chargeback%22%3A%20false%2C%20%22ContractId%22%3A%20null%2C%20%22MerchantId%22%3A%20%22testMerchantId%22%2C%20%22OrderState%22%3A%20%22PaymentAuthorized%22%2C%20%22RateOfferId%22%3A%20%22c754012f-e0fc-4630-9cb5-11c3450f462e%22%2C%20%22ReferenceId%22%3A%20%22123%22%2C%20%22UnderReview%22%3A%20false%2C%20%22ConsumerTotal%22%3A%20100.00%2C%20%22MerchantTotal%22%3A%20100.00%2C%20%22TransactionId%22%3A%20%22e08f6501-2607-4be1-9dba-97d6780dfe9a%22%2C%20%22ConsumerCurrency%22%3A%20%22USD%22%7D&signature=no%2BEojgxrO5JK4wt4EWtbuY9M7h1eVQ9SLezu10X%2Bn4%3D'
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
    <- "POST /v2.21/checkout HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: checkout.rch.how\r\nContent-Length: 756\r\n\r\n"
    <- "request=%7B%22MerchantId%22%3A%22Some-30value-4for3-9test35-f93086cd7crednet1%22%2C%22ReferenceId%22%3A%22123%22%2C%22ConsumerCurrency%22%3A%22USD%22%2C%22Capture%22%3Atrue%2C%22PaymentMethod%22%3A%22VISA%22%2C%22Items%22%3A%5B%7B%22Sku%22%3A%22d99oJA8rkwgQANFJ%22%2C%22ConsumerPrice%22%3A100%2C%22Quantity%22%3A1%7D%5D%2C%22ViaAgent%22%3Atrue%2C%22Consumer%22%3A%7B%22Name%22%3A%22Longbob+Longsen%22%2C%22Email%22%3A%22johndoe%40reach.com%22%2C%22Address%22%3A%221670%22%2C%22City%22%3A%22Miami%22%2C%22Country%22%3A%22US%22%7D%7D&card=%7B%22Name%22%3A%22Longbob+Longsen%22%2C%22Number%22%3A%224444333322221111%22%2C%22Expiry%22%3A%7B%22Month%22%3A3%2C%22Year%22%3A2030%7D%2C%22VerificationCode%22%3A737%7D&signature=5nimSignatUre%3D"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 03 Nov 2022 23:04:01 GMT\r\n"
    -> "Content-Type: application/x-www-form-urlencoded; charset=utf-8\r\n"
    -> "Content-Length: 235\r\n"
    -> "Connection: close\r\n"
    -> "Server: ipCheckoutApi/unreleased ibiHttpServer\r\n"
    -> "Strict-Transport-Security: max-age=60000\r\n"
    -> "Cache-Control: no-cache\r\n"
    -> "Access-Control-Allow-Origin: *\r\n"
    -> "\r\n"
    reading 235 bytes...
    -> "response=%7B%22OrderId%22%3A%22621a0c76-69fb-4c05-854a-e7e731759ad3%22%2C%22UnderReview%22%3Afalse%2C%22Authorized%22%3Atrue%2C%22Completed%22%3Afalse%2C%22Captured%22%3Afalse%7D&signature=23475signature23123%3D"
    read 235 bytes
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SRCUBBED
    <- "POST /v2.21/checkout HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: checkout.rch.how\r\nContent-Length: 756\r\n\r\n"
    <- "request=%7B%22MerchantId%22%3A%22[FILTERED]%22%2C%22ReferenceId%22%3A%22123%22%2C%22ConsumerCurrency%22%3A%22USD%22%2C%22Capture%22%3Atrue%2C%22PaymentMethod%22%3A%22VISA%22%2C%22Items%22%3A%5B%7B%22Sku%22%3A%22d99oJA8rkwgQANFJ%22%2C%22ConsumerPrice%22%3A100%2C%22Quantity%22%3A1%7D%5D%2C%22ViaAgent%22%3Atrue%2C%22Consumer%22%3A%7B%22Name%22%3A%22Longbob+Longsen%22%2C%22Email%22%3A%22johndoe%40reach.com%22%2C%22Address%22%3A%221670%22%2C%22City%22%3A%22Miami%22%2C%22Country%22%3A%22US%22%7D%7D&card=%7B%22Name%22%3A%22Longbob+Longsen%22%2C%22Number%22%3A%22[FILTERED]%22%2C%22Expiry%22%3A%7B%22Month%22%3A3%2C%22Year%22%3A2030%7D%2C%22VerificationCode%22%3A[FILTERED]%7D&signature=[FILTERED]"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Thu, 03 Nov 2022 23:04:01 GMT\r\n"
    -> "Content-Type: application/x-www-form-urlencoded; charset=utf-8\r\n"
    -> "Content-Length: 235\r\n"
    -> "Connection: close\r\n"
    -> "Server: ipCheckoutApi/unreleased ibiHttpServer\r\n"
    -> "Strict-Transport-Security: max-age=60000\r\n"
    -> "Cache-Control: no-cache\r\n"
    -> "Access-Control-Allow-Origin: *\r\n"
    -> "\r\n"
    reading 235 bytes...
    -> "response=%7B%22OrderId%22%3A%22621a0c76-69fb-4c05-854a-e7e731759ad3%22%2C%22UnderReview%22%3Afalse%2C%22Authorized%22%3Atrue%2C%22Completed%22%3Afalse%2C%22Captured%22%3Afalse%7D&signature=[FILTERED]"
    read 235 bytes
    Conn close
    POST_SRCUBBED
  end
end
