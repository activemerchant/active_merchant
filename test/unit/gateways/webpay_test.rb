require 'test_helper'

class WebpayTest < Test::Unit::TestCase
  def setup
    @gateway = WebpayGateway.new(:login => 'login')

    @credit_card = credit_card()
    @amount = 400
    @refund_amount = 200

    @options = {
      :billing_address => address(),
      :description => 'Test Purchase'
    }
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

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_purchase_response(true))

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
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_request_always_uses_live_mode_to_determine_test_request
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response(:livemode => true))

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_instance_of Response, response
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
    assert_match /^Invalid response received from the WebPay API/, response.message
  end

  def test_add_customer
    post = {}
    @gateway.send(:add_customer, post, {:customer => "test_customer"})
    assert_equal "test_customer", post[:customer]
  end

  def test_doesnt_add_customer_if_card
    post = { :card => 'foo' }
    @gateway.send(:add_customer, post, {:customer => "test_customer"})
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

  def test_purchase_without_card_or_customer
    assert_raises ArgumentError do
      @gateway.purchase(@amount, nil)
    end
  end

  def test_metadata_header
    @gateway.expects(:ssl_request).once.with {|method, url, post, headers|
      headers && headers['X-Webpay-Client-User-Metadata'] == {:ip => '1.1.1.1'}.to_json
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(:ip => '1.1.1.1'))
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response(refunded=false)
    <<-RESPONSE
{
  "amount": 400,
  "created": 1309131571,
  "currency": "jpy",
  "description": "Test Purchase",
  "id": "ch_test_charge",
  "livemode": false,
  "object": "charge",
  "paid": true,
  "refunded": #{refunded},
  "card": {
    "country": "JP",
    "exp_month": 9,
    "exp_year": #{Time.now.year + 1},
    "last4": "4242",
    "object": "card",
    "type": "Visa"
  }
}
    RESPONSE
  end

  def successful_partially_refunded_response(options = {})
    options = {:livemode=>false}.merge!(options)
    <<-RESPONSE
{
  "amount": 400,
  "amount_refunded": 200,
  "created": 1309131571,
  "currency": "jpy",
  "description": "Test Purchase",
  "id": "ch_test_charge",
  "livemode": #{options[:livemode]},
  "object": "charge",
  "paid": true,
  "refunded": true,
  "card": {
    "country": "JP",
    "exp_month": 9,
    "exp_year": #{Time.now.year + 1},
    "last4": "4242",
    "object": "card",
    "type": "Visa"
  }
}
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-RESPONSE
    {
      "error": {
        "code": "incorrect_number",
        "param": "number",
        "type": "card_error",
        "message": "Your card number is incorrect"
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
