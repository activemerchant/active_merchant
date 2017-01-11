require 'test_helper'

class KomojuTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = KomojuGateway.new(:login => 'login')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '12345',
      :locale => 'ja',
      :description => 'Store Purchase',
      :tax => "10",
      :ip => "192.168.0.1",
      :email => "valid@email.com",
      :browser_language => "en",
      :browser_user_agent => "user_agent"
    }
  end

  def test_successful_credit_card_purchase
    successful_response = successful_credit_card_purchase_response
    @gateway.expects(:ssl_request).returns(JSON.generate(successful_response))

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal successful_response["id"], response.authorization
    assert response.test?
  end

  def test_successful_credit_card_purchase_options
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match('"amount":"100"', data)
      assert_match('"locale":"ja"', data)
      assert_match('"description":"Store Purchase"', data)
      assert_match('"currency":"JPY"', data)
      assert_match('"external_order_num":"12345"', data)
      assert_match('"tax":"10"', data)
    end.respond_with(JSON.generate(successful_credit_card_purchase_response))
  end

  def test_successful_credit_card_purchase_with_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, "tok_xxx", @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match('"payment_details":"tok_xxx"', data)
    end.respond_with(JSON.generate(successful_credit_card_purchase_response))
  end

  def test_successful_store_payment_details
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/tokens$/, endpoint)
      assert_match({ payment_details: request_payment_details }.to_json, data)
    end.respond_with(JSON.generate(successful_credit_card_store_response))
  end

  def test_failed_purchase
    raw_response = mock
    raw_response.expects(:body).returns(JSON.generate(failed_purchase_response))
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "missing_parameter", response.error_code
    assert response.test?
  end

  def test_detected_fraud
    raw_response = mock
    raw_response.expects(:body).returns(JSON.generate(detected_fraud_response))
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_request).raises(exception)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "fraudulent", response.error_code
    assert response.test?
  end

  def test_successful_credit_card_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(10,  "7e8c55a54256ce23e387f2838c", @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match('"amount":10', data)
    end.respond_with(JSON.generate(successful_credit_card_refund_response))

    assert_equal successful_credit_card_refund_response["id"], response.authorization
    assert response.test?
  end

  def test_successful_credit_card_void
    successful_response = successful_credit_card_refund_response
    @gateway.expects(:ssl_request).returns(JSON.generate(successful_response))

    response = @gateway.void("7e8c55a54256ce23e387f2838c", @options)
    assert_success response

    assert_equal successful_response["id"], response.authorization
  end

  private

  def successful_credit_card_purchase_response
    {
      "id" => "7e8c55a54256ce23e387f2838c",
      "resource" => "payment",
      "status" => "captured",
      "amount" => 100,
      "tax" => 8,
      "payment_deadline" => nil,
      "payment_details" => response_payment_details,
      "payment_method_fee" => 0,
      "total" => 108,
      "currency" => "JPY",
      "description" => "Store Purchase",
      "subscription" => nil,
      "captured_at" => "2015-03-20T04:51:48Z",
      "metadata" => {
        "order_id" => "262f2a92-542c-4b4e-a68b-5b6d54a438a8"
      },
      "created_at" => "2015-03-20T04:51:48Z"
    }
  end

  def successful_credit_card_refund_response
    {
      "id" => "7e8c55a54256ce23e387f2838c",
      "resource" => "payment",
      "status" => "refunded",
      "amount" => 100,
      "tax" => 8,
      "payment_deadline" => nil,
      "payment_details" => response_payment_details,
      "payment_method_fee" => 0,
      "total" => 108,
      "currency" => "JPY",
      "description" => "Store Purchase",
      "subscription" => nil,
      "captured_at" => nil,
      "metadata" => {
        "order_id" => "262f2a92-542c-4b4e-a68b-5b6d54a438a8"
      },
      "created_at" => "2015-03-20T04:51:48Z"
    }
  end

  def successful_credit_card_store_response
    {
      "id" => "tok_7e8a1078428bf050d7d9a867b436ff12f9aafc84d04ee83a4dec36beda14bb055uy99wsx59ekg0zacwvsfqezg",
      "resource" => "token",
      "created_at" => "2015-03-21T07:29:22Z",
      "payment_details" => response_payment_details
    }
  end

  def failed_purchase_response
    {
      "error" => {
        "code" => "missing_parameter",
        "message" => "A required parameter (currency) is missing",
        "param" => "currency"
      }
    }
  end

  def detected_fraud_response
    {
      "error" => {
        "code" => "fraudulent",
        "message" => "The payment could not be completed.",
        "param" => nil
      }
    }
  end

  def request_payment_details
    {
      "type" => "credit_card",
      "number" => @credit_card.number,
      "month" => @credit_card.month,
      "year" => @credit_card.year,
      "verification_value" => @credit_card.verification_value,
      "given_name" => @credit_card.first_name,
      "family_name" => @credit_card.last_name,
      "email" => @options[:email]
    }
  end

  def response_payment_details
    {
      "type" => "credit_card",
      "brand" => "visa",
      "last_four_digits" => @credit_card.number[-1..-4],
      "month" => @credit_card.month,
      "year" => @credit_card.year
    }
  end
end
