require 'test_helper'

class KomojuTest < Test::Unit::TestCase
  def setup
    @gateway = KomojuGateway.new(:login => 'login')

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
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
    @gateway.expects(:ssl_post).returns(JSON.generate(successful_response))

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal successful_response["id"], response.authorization
    assert response.test?
  end

  def test_failed_purchase
    raw_response = mock
    raw_response.expects(:body).returns(JSON.generate(failed_purchase_response))
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_post).raises(exception)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "missing_parameter", response.error_code
    assert response.test?
  end

  def test_detected_fraud
    raw_response = mock
    raw_response.expects(:body).returns(JSON.generate(detected_fraud_response))
    exception = ActiveMerchant::ResponseError.new(raw_response)

    @gateway.expects(:ssl_post).raises(exception)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "fraudulent", response.error_code
    assert response.test?
  end

  def test_successful_credit_card_refund
    successful_response = successful_credit_card_refund_response
    @gateway.expects(:ssl_post).returns(JSON.generate(successful_response))

    response = @gateway.refund(@amount,  "7e8c55a54256ce23e387f2838c", @options)
    assert_success response

    assert_equal successful_response["id"], response.authorization
    assert response.test?
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
      "payment_details" => {
        "type" => "credit_card",
        "brand" => "visa",
        "last_four_digits" => "2220",
        "month" => 9,
        "year" => 2016
      },
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
      "payment_details" => {
        "type" => "credit_card",
        "brand" => "visa",
        "last_four_digits" => "2220",
        "month" => 9,
        "year" => 2016
      },
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
end
