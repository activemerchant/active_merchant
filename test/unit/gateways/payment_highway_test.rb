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
end
