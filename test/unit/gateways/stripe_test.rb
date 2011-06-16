require 'rubygems'
require 'json'

require 'test_helper'

class StripeTest < Test::Unit::TestCase
  def setup
    @gateway = StripeGateway.new(:login => 'login')

    @credit_card = credit_card()
    @amount = 100

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

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /^Invalid response received from the Stripe API/, response.message
  end

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end

  def test_ensure_does_not_respond_to_capture
    assert !@gateway.respond_to?(:capture) || @gateway.method(:capture).owner != @gateway.class
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

  def test_gateway_without_credentials
    assert_raises ArgumentError do
      StripeGateway.new
    end
  end

  def test_purchase_without_card_or_customer
    assert_raises ArgumentError do
      @gateway.purchase(@amount, nil)
    end
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response(refunded=false)
    <<-RESPONSE
    {
      "attempted": true,
      "refunded": #{refunded},
      "paid": true,
      "amount": 400,
      "card": {
        "type": "Visa",
        "country": "US",
        "exp_month": 9,
        "last4": "4242",
        "exp_year": #{Time.now.year + 1},
        "object": "card",
        "id": "cc_test_card"
      },
      "id": "ch_test_charge",
      "livemode": false,
      "description": "Test Purchase",
      "currency": "usd",
      "object": "charge",
      "created": 1307309607
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
