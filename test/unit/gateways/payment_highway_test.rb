require 'test_helper'

class PaymentHighwayTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentHighwayGateway.new(sph_account: "account", sph_merchant: "merchant", account_key: "key", account_secret: "secret")
    @credit_card = credit_card
    @amount = 1000

    @options = {
      order_id: '1',
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:ssl_post).returns(transaction_id_generation_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'Request successful.', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    @gateway.expects(:ssl_post).returns(transaction_id_generation_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal PaymentHighwayGateway::RESPONSE_CODE_MAPPING[200], response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, "ebf19bf4-2ea7-4a29-8a90-f1abec66c57d", @credit_card)
    assert_success refund
    assert_equal PaymentHighwayGateway::RESPONSE_CODE_MAPPING[100], refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert refund = @gateway.refund(@amount, "ebf19bf4-2ea7-4a29-8a90-f1abec66c57d", @credit_card)
    assert_failure refund
    assert_equal PaymentHighwayGateway::RESPONSE_CODE_MAPPING[200], refund.message
  end

  def test_scrub
    assert !@gateway.supports_scrubbing?
  end

  def test_successful_order_status
    @gateway.expects(:ssl_get).returns(successful_order_status_response)

    assert response = @gateway.order_status("order-id")
    assert_success response
    assert_equal PaymentHighwayGateway::RESPONSE_CODE_MAPPING[100], response.message
  end

  def test_successful_transaction_status
    @gateway.expects(:ssl_get).returns(successful_transaction_response)

    assert response = @gateway.transaction_status("ebf19bf4-2ea7-4a29-8a90-f1abec66c57d")
    assert_success response
    assert_equal PaymentHighwayGateway::RESPONSE_CODE_MAPPING[100], response.message
  end

  private

  def pre_scrubbed
    %q(
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    )
  end

  def post_scrubbed
    %q(
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    )
  end

  def transaction_id_generation_response
    {
      "id":"ebf19bf4-2ea7-4a29-8a90-f1abec66c57d",
      "result":
      {
        "code":100,
        "message":"OK"
      }
    }.to_json
  end

  def successful_purchase_response
    {
      "result":
      {
        "code":100,
        "message":"OK"
      }
    }.to_json
  end

  def failed_purchase_response
    {
      "result":
      {
        "code": 200,
        "message": "Authorization failed"
      }
    }.to_json
  end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  def successful_capture_response
  end

  def failed_capture_response
  end

  def successful_refund_response
    {
      "result":
      {
        "code":100,
        "message":"OK"
      }
    }.to_json
  end

  def failed_refund_response
    {
      "result":
      {
        "code":200,
        "message":"Failed"
      }
    }.to_json
  end

  def successful_void_response
  end

  def failed_void_response
  end

  def successful_order_status_response
    {
      "transactions":
      [
        {
          "id":"f9cc5892-d3e7-486f-9fb3-cf9a42887118",
          "acquirer":
          {
            "id":"nets",
            "name":"Nets"
          },
          "type":"debit",
          "amount":100,
          "current_amount":100,
          "currency":"EUR",
          "timestamp":"2015-07-03T20:16:41Z",
          "modified":"2015-06-27T13:54:05Z",
          "filing_code":"150703000026",
          "status":
          {
            "state":"failed",
            "code":7000
          },
          "card":
          {
            "type":"Visa",
            "partial_pan":"1234",
            "expire_year":"2017",
            "expire_month":"11",
            "cvc_required":"not_tested"
          },
          "reverts":[]
        },
        {
          "id":"ca02843a-9942-4944-a1b4-59ade8cc3eca",
          "acquirer":
          {
            "id":"nets",
            "name":"Nets"
          },
          "type":"debit",
          "amount":100,
          "current_amount":0,
          "currency":"EUR",
          "timestamp":"2015-07-03T19:22:03Z",
          "modified":"2015-06-27T13:51:27Z",
          "filing_code":"150703000024",
          "authorization_code":"979855",
          "token":"7906486c-beea-4f69-9f55-29f7ab4b6bef",
          "status":
          {
            "state":"reverted",
            "code":5700
          },
          "card":
          {
            "type":"Visa",
            "partial_pan":"0024",
            "expire_year":"2017",
            "expire_month":"11",
            "cvc_required":"no"
          },
          "reverts":
          [
            {
              "type":"cancellation",
              "status":
              {
                "state":"ok",
                "code":4000
              },
              "amount":100,
              "timestamp":"2015-07-03T20:14:03Z",
              "modified":"2015-06-27T13:51:27Z",
              "filing_code":"150703000024"
            }
          ]
        }
      ],
      "result":
      {
        "code":100,
        "message":"OK"
      }
    }.to_json
  end

  def successful_transaction_response
    {
      "transaction":
      {
        "id":"5a457896-1b74-48e2-a012-0f1016c64900",
        "acquirer":
        {
          "id":"nets",
          "name":"Nets"
        },
        "type":"debit",
        "amount":9999,
        "current_amount":9999,
        "currency":"EUR",
        "timestamp":"2015-04-28T12:11:12Z",
        "modified":"2015-04-28T12:11:12Z",
        "filing_code":"150428011232",
        "authorization_code":"639283",
        "status":
        {
          "state":"ok",
          "code":4000
        },
        "card":
        {
          "type":"Visa",
          "partial_pan":"0024",
          "expire_year":"2017",
          "expire_month":"11"
        }
      },
      "result":
      {
        "code":100,
        "message":"OK"
      }
    }.to_json
  end
end
