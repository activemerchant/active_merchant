require 'test_helper'

class RemoteFlowTest < Test::Unit::TestCase
  def setup
    @gateway = FlowGateway.new(fixtures(:flow))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4012888888881881')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'USD',
      customer: {
        first_name: 'Joe',
        last_name: 'Smith'
      }
    }
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    card = response.params["object"]
    assert card.id
    assert card.token
    assert_equal @credit_card.last_digits, card.last4
    assert_equal @credit_card.brand, card.type.value
    assert_equal @credit_card.name, card.name
    assert_equal @credit_card.month, card.expiration.month
    assert_equal @credit_card.year, card.expiration.year
  end

  def test_successful_authorize_and_capture_from_stored_card
    response = @gateway.store(@credit_card)
    assert_success response
    card = response.params["object"]

    auth = @gateway.authorize(@amount, card.token, @options)
    assert_success auth
    authorization = auth.params["object"]

    assert response = @gateway.capture(@amount, auth.authorization)
    assert_success response
    assert_equal 'Transaction approved', response.message
    capture = response.params["object"]
    assert capture.key
    assert capture.id
    assert_equal @amount, capture.amount.to_i * 100
    assert_equal @options[:currency], capture.currency
    assert_equal authorization.id, capture.authorization.id
  end

  def test_failed_authorize_with_merchant_of_record
    response = @gateway.store(@credit_card)
    assert_success response
    card = response.params['object']

    response = @gateway.authorize(nil, card.token, @options.merge(order_id: "ORD-123"))
    assert_failure response
    assert_equal "Order number either does not exist or you are not authorized to access this order", response.message
    assert_equal "generic_error", response.error_code
  end

  def test_successful_purchase
    response = @gateway.store(@credit_card)
    assert_success response
    card = response.params["object"]

    response = @gateway.purchase(@amount, card.token, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
    capture = response.params["object"]
    assert capture.key
    assert capture.id
    assert capture.authorization.id
    assert_equal @amount, capture.amount.to_i * 100
    assert_equal @options[:currency], capture.currency
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      customer: {
        first_name: "Joe",
        last_name: "Smith"
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_failed_purchase
    # 2026 means AVS pass, auth decline due to fraud
    response = @gateway.purchase(202600, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card was declined', response.message
    assert_equal 'processing_error', response.error_code
    assert_equal 'M', response.cvv_result['code']
  end

  def test_failed_authorize
    # 2025 means AVS pass, auth decline due to CVC check
    response = @gateway.authorize(202500, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card was declined', response.message
    assert_equal 'invalid_cvc', response.error_code
    assert_equal 'N', response.cvv_result['code']
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'invalida authorization')
    assert_failure response
    assert_equal 'Authorization ID not found', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization)
    assert_success response
    assert_equal 'Transaction approved', response.message
    refund = response.params["object"]
    assert_equal @amount, refund.amount.to_i * 100
    assert_equal @options[:currency], refund.currency
    assert_equal 1, refund.captures.length
  end

 #  def test_partial_refund
 #    purchase = @gateway.purchase(@amount, @credit_card, @options)
 #    assert_success purchase

 #    assert refund = @gateway.refund(@amount-1, purchase.authorization)
 #    assert_success refund
 #  end

 #  def test_failed_refund
 #    response = @gateway.refund(@amount, '')
 #    assert_failure response
 #    assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
 #  end

  def test_successful_void
    assert response = @gateway.store(@credit_card)
    assert_success response
    card = response.params["object"]
    response = @gateway.authorize(@amount, card.token, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_failed_void_with_empty_authorization
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Not Found', response.message
  end

  def test_failed_void_with_invalid_authorization
    response = @gateway.void('invalid')
    assert_failure response
    assert_equal 'Not Found', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options.merge(amount: 202000))
    assert_failure response
    assert_match %r{Your card was declined}, response.message
    assert_match "expired_card", response.error_code
  end

  def test_invalid_login
    gateway = FlowGateway.new(api_key: 'foobar', organization: 'invalid')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Not Found}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
