require 'test_helper'

class WorldpayOnlinePaymentsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayOnlinePaymentsGateway.new(
      client_key: "T_C_NOT_VALID",
      service_key: "T_S_NOT_VALID"
    )

    @credit_card = credit_card
    @amount = 1000

    @@credit_card = credit_card('4444333322221111')
    @options = {:order_id => 1}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_token_response)
    #@gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'REPLACE', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
  end

  def test_failed_authorize
  end

  def test_successful_capture
  end

  def test_failed_capture
  end

  def test_successful_refund
  end

  def test_failed_refund
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  private

  def successful_token_response
    %({
      "token" : "valid_token",
      "reusable":"false",
      "paymentMethod" : {
        "type" : "ObfuscatedCard",
        "name" : "Shopper Name",
        "expiryMonth" : 2,
        "expiryYear" : 2016,
        "issueNumber" : 1,
        "startMonth" : 1,
        "startYear" : 2011,
        "cardType" : "MASTERCARD",
        "maskedCardNumber" : "**** **** **** 1111"
      }
    })
  end
  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_worldpay_online_payments_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response
    %({
      "token" : "invalid_token",
      "reusable":"false",
      "paymentMethod" : {
        "type" : "ObfuscatedCard",
        "name" : "Shopper Name",
        "expiryMonth" : 2,
        "expiryYear" : 2016,
        "issueNumber" : 1,
        "startMonth" : 1,
        "startYear" : 2011,
        "cardType" : "MASTERCARD",
        "maskedCardNumber" : "**** **** **** 1111"
      }
    })
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
  end

  def failed_refund_response
  end

  def successful_void_response
  end

  def failed_void_response
  end
end
