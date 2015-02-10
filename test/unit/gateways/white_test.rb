require 'test_helper'

class WhiteTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WhiteGateway.new(login: 'test_sec_k_xxx')

    @credit_card = credit_card()
    @amount = 1000

    @options = {
      description: 'Test Purchase',
      email: 'john@example.com',
      ip: '192.168.0.1'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'Transaction processed', response.message
    assert_equal 'ch_275560f990739bb78059f43fec2d', response.authorization
    assert response.test?
  end

  def test_declined_purchase
    @gateway.expects(:ssl_request).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 'Charge was declined.', response.message
    assert_equal 'card_declined', response.error_code
    assert_equal 'ch_275560f990739bb78059f43fec2d', response.authorization
    assert response.test?
  end

  def test_invalid_purchase
    @gateway.expects(:ssl_request).returns(validation_error_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal "Request params are invalid. Amount: can't be blank, is not a number. Cvc: can't be blank", response.message

    assert_equal 'unprocessable_entity', response.error_code
    assert_nil response.authorization
    assert response.test?
  end

  def test_invalid_purchase_with_token
    @gateway.expects(:ssl_request).returns(validation_error_response_for_token)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 'Request params are invalid. Card: token has already been used', response.message

    assert_equal 'unprocessable_entity', response.error_code
    assert_nil response.authorization
    assert response.test?
  end

  def test_invalid_purchase_with_customer_id
    @gateway.expects(:ssl_request).returns(validation_error_response_for_customer)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 'Request params are invalid. Customer_id: customer should have a default card', response.message

    assert_equal 'unprocessable_entity', response.error_code
    assert_nil response.authorization
    assert response.test?
  end

  def test_add_credit_card_with_token
    post = {}
    @gateway.send(:add_payment_method, post, "tok_123", {})
    assert_equal post[:card], "tok_123"
  end

  def test_add_payment_method_with_customer
    post = {}
    @gateway.send(:add_payment_method, post, "cus_123", {})
    assert_equal post[:customer_id], "cus_123"
  end

  def test_add_payment_method_with_customer_card
    post = {}
    @gateway.send(:add_payment_method, post, "cus_123", {card_id: 'card_123'})
    assert_equal post[:customer_id], "cus_123"
    assert_equal post[:card], "card_123"
  end

  private

  def successful_purchase_response
    <<-RESPONSE
    {
      "id":"ch_275560f990739bb78059f43fec2d",
      "amount": 10500,
      "currency": "BHD",
      "description": "Test charge",
      "state": "captured",
      "captured_amount": 100,
      "refunded_amount": 0,
      "created_at":"2014-12-26T10:18:57.539Z",
      "statement_description": "Test descriptor",
      "object": "charge",
      "email": "hello@example.com",
      "ip": "192.168.99.100",
      "card": {
        "object": "card",
        "id": "{id}",
        "last4": "4242",
        "brand": "visa",
        "exp_month": 12,
        "exp_year": 2020,
        "holder": "John Doe",
        "customer_id":null
      }
    }
    RESPONSE
  end

  def declined_purchase_response
    <<-RESPONSE
    {
      "error": {
        "type": "banking",
        "message": "Charge was declined.",
        "code": "card_declined",
        "extras": {
          "charge": "ch_275560f990739bb78059f43fec2d"
        }
      }
    }
    RESPONSE
  end

  def validation_error_response
    <<-RESPONSE
    {
      "error": {
        "type": "request",
        "message": "Request params are invalid.",
        "code": "unprocessable_entity",
        "extras": {
          "amount": ["can't be blank", "is not a number"],
          "card": {
            "cvc": ["can't be blank"]
          }
        }
      }
    }
    RESPONSE
  end

  def validation_error_response_for_token
    <<-RESPONSE
    {
      "error": {
        "type": "request",
        "message": "Request params are invalid.",
        "code": "unprocessable_entity",
        "extras": {
          "card": ["token has already been used"]
        }
      }
    }
    RESPONSE
  end

  def validation_error_response_for_customer
    <<-RESPONSE
    {
      "error": {
        "type": "request",
        "message": "Request params are invalid.",
        "code": "unprocessable_entity",
        "extras": {
          "customer_id":["customer should have a default card"]
        }
      }
    }
    RESPONSE
  end
end
