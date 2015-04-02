require 'test_helper'

class WebpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WebpayGateway.new(:login => 'login')

    @credit_card = credit_card()
    @amount = 40000
    @refund_amount = 20000

    @options = {
      :billing_address => address(),
      :description => 'Test Purchase'
    }
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, "ch_test_charge")
    assert_success response
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_appropriate_purchase_amount
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal @amount / 100, response.params["amount"]
  end

  def test_successful_purchase_with_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, "tok_xxx")
    end.check_request do |method, endpoint, data, headers|
      assert_match(/card=tok_xxx/, data)
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_refunded_response)

    assert response = @gateway.void('ch_test_charge')
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_request_always_uses_live_mode_to_determine_test_request
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response(:livemode => true))

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response

    assert !response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    # unsuccessful request defaults to live
    assert !response.test?
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{^Invalid response received from the WebPay API}, response.message
  end

  def test_add_customer
    post = {}
    @gateway.send(:add_customer, post, 'card_token', {:customer => "test_customer"})
    assert_equal "test_customer", post[:customer]
  end

  def test_doesnt_add_customer_if_card
    post = {}
    @gateway.send(:add_customer, post, @credit_card, {:customer => "test_customer"})
    assert !post[:customer]
  end

  def test_add_customer_data
    post = {}
    @gateway.send(:add_customer_data, post, {:description => "a test customer"})
    assert_equal "a test customer", post[:description]
  end

  def test_add_address
    post = {:card => {}}
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:zip], post[:card][:address_zip]
    assert_equal @options[:billing_address][:state], post[:card][:address_state]
    assert_equal @options[:billing_address][:address1], post[:card][:address_line1]
    assert_equal @options[:billing_address][:address2], post[:card][:address_line2]
    assert_equal @options[:billing_address][:country], post[:card][:address_country]
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_gateway_without_credentials
    assert_raises ArgumentError do
      WebpayGateway.new
    end
  end

  def test_metadata_header
    @gateway.expects(:ssl_request).once.with {|method, url, post, headers|
      headers && headers['X-Webpay-Client-User-Metadata'] == {:ip => '1.1.1.1'}.to_json
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(:ip => '1.1.1.1'))
  end

  private

  def successful_authorization_response
    <<-RESPONSE
{
  "id": "ch_test_charge",
  "object": "charge",
  "livemode": false,
  "currency": "jpy",
  "description": "ActiveMerchant Test Purchase",
  "amount": 40000,
  "amount_refunded": 0,
  "customer": null,
  "recursion": null,
  "created": 1309131571,
  "paid": false,
  "refunded": false,
  "failure_message": null,
  "card": {
    "object": "card",
    "exp_year": #{Time.now.year + 1},
    "exp_month": 11,
    "fingerprint": "215b5b2fe460809b8bb90bae6eeac0e0e0987bd7",
    "name": "LONGBOB LONGSEN",
    "country": "JP",
    "type": "Visa",
    "cvc_check": "pass",
    "last4": "4242"
  },
  "captured": false,
  "expire_time": 1309736371,
  "fees": [

  ]
}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
{
  "id": "ch_test_charge",
  "object": "charge",
  "livemode": false,
  "currency": "jpy",
  "description": "ActiveMerchant Test Purchase",
  "amount": 40000,
  "amount_refunded": 0,
  "customer": null,
  "recursion": null,
  "created": 1309131571,
  "paid": true,
  "refunded": false,
  "failure_message": null,
  "card": {
    "object": "card",
    "exp_year": #{Time.now.year + 1},
    "exp_month": 11,
    "fingerprint": "215b5b2fe460809b8bb90bae6eeac0e0e0987bd7",
    "name": "LONGBOB LONGSEN",
    "country": "JP",
    "type": "Visa",
    "cvc_check": "pass",
    "last4": "4242"
  },
  "captured": true,
  "expire_time": 1309736371,
  "fees": [
    {
      "object": "fee",
      "transaction_type": "payment",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": 1300,
      "created": 1408585142
    }
  ]
}
    RESPONSE
  end

  # Place raw successful response from gateway here
  def successful_purchase_response(refunded=false)
    <<-RESPONSE
{
  "id": "ch_test_charge",
  "object": "charge",
  "livemode": false,
  "currency": "jpy",
  "description": "ActiveMerchant Test Purchase",
  "amount": 400,
  "amount_refunded": 0,
  "customer": null,
  "recursion": null,
  "created": 1408585273,
  "paid": true,
  "refunded": false,
  "failure_message": null,
  "card": {
    "object": "card",
    "exp_year": #{Time.now.year + 1},
    "exp_month": 11,
    "fingerprint": "215b5b2fe460809b8bb90bae6eeac0e0e0987bd7",
    "name": "LONGBOB LONGSEN",
    "country": "JP",
    "type": "Visa",
    "cvc_check": "pass",
    "last4": "4242"
  },
  "captured": true,
  "expire_time": null,
  "fees": [
    {
      "object": "fee",
      "transaction_type": "payment",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": 1300,
      "created": 1408585273
    }
  ]
}
    RESPONSE
  end

  def successful_refunded_response
    <<-RESPONSE
{
  "id": "ch_test_charge",
  "object": "charge",
  "livemode": false,
  "currency": "jpy",
  "description": "ActiveMerchant Test Purchase",
  "amount": 400,
  "amount_refunded": 400,
  "customer": null,
  "recursion": null,
  "created": 1408585273,
  "paid": true,
  "refunded": true,
  "failure_message": null,
  "card": {
    "object": "card",
    "exp_year": #{Time.now.year + 1},
    "exp_month": 11,
    "fingerprint": "215b5b2fe460809b8bb90bae6eeac0e0e0987bd7",
    "name": "KEI KUBO",
    "country": "JP",
    "type": "Visa",
    "cvc_check": "pass",
    "last4": "4242"
  },
  "captured": true,
  "expire_time": null,
  "fees": [
    {
      "object": "fee",
      "transaction_type": "payment",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": 1300,
      "created": 1408585273
    },
    {
      "object": "fee",
      "transaction_type": "refund",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": -1300,
      "created": 1408585461
    }
  ]
}
    RESPONSE
  end

  def successful_partially_refunded_response(options = {})
    options = {:livemode=>false}.merge!(options)
    <<-RESPONSE
{
  "id": "ch_test_charge",
  "object": "charge",
  "livemode": #{options[:livemode]},
  "currency": "jpy",
  "description": "ActiveMerchant Test Purchase",
  "amount": 400,
  "amount_refunded": 200,
  "customer": null,
  "recursion": null,
  "created": 1408584994,
  "paid": true,
  "refunded": false,
  "failure_message": null,
  "card": {
    "object": "card",
    "exp_year": #{Time.now.year + 1},
    "exp_month": 11,
    "fingerprint": "215b5b2fe460809b8bb90bae6eeac0e0e0987bd7",
    "name": "KEI KUBO",
    "country": "JP",
    "type": "Visa",
    "cvc_check": "pass",
    "last4": "4242"
  },
  "captured": true,
  "expire_time": 1409189794,
  "fees": [
    {
      "object": "fee",
      "transaction_type": "payment",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": 1300,
      "created": 1408585142
    },
    {
      "object": "fee",
      "transaction_type": "refund",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": -1300,
      "created": 1408585699
    },
    {
      "object": "fee",
      "transaction_type": "payment",
      "transaction_fee": 0,
      "rate": 3.25,
      "amount": 650,
      "created": 1408585699
    }
  ]
}
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-RESPONSE
{
  "error": {
    "message": "The card number is invalid. Make sure the number entered matches your credit card.",
    "caused_by": "buyer",
    "param": "number",
    "type": "card_error",
    "code": "incorrect_number"
  }
}
    RESPONSE
  end

  # Place raw invalid JSON from gateway here
  def invalid_json_response
    <<-RESPONSE
    {
       foo : bar
    }
    RESPONSE
  end
end
