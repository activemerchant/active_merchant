require 'test_helper'

class ConektaTest < Test::Unit::TestCase
  def setup
    @gateway = ConektaGateway.new(:key => "key_eYvWV7gSDkNYXsmr")

    @amount = 300

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4242424242424242",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

    @declined_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => "4000000000000002",
      :verification_value => "183",
      :month              => "01",
      :year               => "2018",
      :first_name         => "Mario F.",
      :last_name          => "Moreno Reyes"
    )

   @options = {
      device_fingerprint: "41l9l92hjco6cuekf0c7dq68v4",
      description: 'Blue clip',
      customer: "Mario Reyes",
      email: "mario@gmail.com",
      phone: "1234567890",
      billing_address: {
        address1: "Rio Missisipi #123",
        address2: "Paris",
        city: "Guerrero",
        country: "Mexico",
        zip: "5555",
        phone: "12345678",
      },
      carrier: "Estafeta"
    }

    @spreedly_options = {
      description: "{
        \"device_fingerprint\":\"41l9l92hjco6cuekf0c7dq68v4\",
        \"description\":\"Blue clip\",
        \"customer\":\"Mario Reyes\",
        \"email\":\"mario@gmail.com\",
        \"phone\":\"1234567890\",
        \"ip\":\"127.0.0.1\",
        \"billing_address\": {
          \"address1\": \"Rio Missisipi #123\",
          \"address2\": \"Paris\",
          \"city\": \"Guerrero\",
          \"country\": \"Mexico\",
          \"zip\": \"5555\",
          \"name\": \"Mario Reyes\",
          \"phone\": \"12345678\"
        }
      }"
    }
  end

  def test_successful_purchase_using_spreedly
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @spreedly_options)
    assert_instance_of Response, response
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_successful_tokenized_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, 'tok_xxxxxxxxxxxxxxxx', @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    assert response = @gateway.refund(@amount, "1", @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_instance_of Response, response
    assert_equal nil, response.message
    assert response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    assert response = @gateway.capture(@amount, "1", @options)
    assert_failure response
    assert response.test?
  end

  def test_invalid_key
    gateway = ConektaGateway.new(:key => 'invalid_token')
    gateway.expects(:ssl_request).returns(failed_login_response)
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    {
      "id" => "567837c719ce888f130010ff",
      "livemode" => false,
      "created_at" => 1450719175,
      "status" => "paid",
      "currency" => "MXN",
      "description" => "Active Merchant Purchase",
      "reference_id" => "#1450719153.1",
      "object" => "charge",
      "amount" => 57421,
      "paid_at" => 1450719180,
      "fee" => 2221,
      "customer_id" => "",
      "refunds" => [

      ],
      "payment_method" => {
        "name" => "Tobias Luetke",
        "exp_month" => "09",
        "exp_year" => "16",
        "auth_code" => "000000",
        "object" => "card_payment",
        "last4" => "1111",
        "brand" => "visa",
        "address" => {
          "street1" => "123 Amoebobacterieae St",
          "city" => "Ottawa",
          "state" => "ON",
          "zip" => "K2P0V6",
          "country" => "CA"
        }
      },
      "details" => {
        "name" => "bob@customer.com",
        "email" => "bob@customer.com",
        "line_items" => [

        ],
        "billing_address" => {
          "street1" => "123 Amoebobacterieae St",
          "city" => "Ottawa",
          "state" => "ON",
          "zip" => "K2P0V6",
          "country" => "MX",
          "phone" => "(555)555-5555",
        }
      }
    }.to_json
  end

  def failed_purchase_response
    {
      'message' => 'The card was declined',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_bank_purchase_response
    {
      'message' => 'The minimum purchase is 15 MXN pesos for bank transfer payments',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_refund_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def failed_void_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def successful_authorize_response
    {
      "id" => "567845ae2412299ec80012d9",
      "livemode" => false,
      "created_at" => 1450722734,
      "status" => "pre_authorized",
      "currency" => "MXN",
      "description" => "Active Merchant Purchase",
      "reference_id" => "#1450722732.1",
      "object" => "charge",
      "amount" => 57620,
      "fee" => 2228,
      "customer_id" => "",
      "refunds" => [

      ],
      "payment_method" => {
        "name" => "Tobias Luetke",
        "exp_month" => "09",
        "exp_year" => "16",
        "auth_code" => "000000",
        "object" => "card_payment",
        "last4" => "1111",
        "brand" => "visa",
        "address" => {
          "street1" => "123 Amoebobacterieae St",
          "city" => "Ottawa",
          "state" => "ON",
          "zip" => "K2P0V6",
          "country" => "CA"
        }
      },
      "details" => {
        "name" => "bob@customer.com",
        "email" => "bob@customer.com",
        "line_items" => [

        ],
        "billing_address" => {
          "street1" => "123 Amoebobacterieae St",
          "city" => "Ottawa",
          "state" => "ON",
          "zip" => "K2P0V6",
          "country" => "MX",
          "phone" => "(555)555-5555",
        }
      }
    }.to_json
  end

  def failed_authorize_response
    {
      'message' => 'The card was declined',
      'type' => 'invalid_parameter_error',
      'param' => ''
    }.to_json
  end

  def failed_capture_response
    {
      'object' => 'error',
      'type' => 200,
      'message' => 'The charge does not exist or it is not suitable for this operation'
    }.to_json
  end

  def failed_login_response
    {
      'object' => 'error',
      'type' => 'authentication_error',
      'message' => 'Unrecognized authentication token'
    }.to_json
  end
end
