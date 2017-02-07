require 'test_helper'

class RemoteOmiseTest < Test::Unit::TestCase
  def setup
    @gateway = OmiseGateway.new(fixtures(:omise))
    @amount  = 8888
    @credit_card   = credit_card('4242424242424242')
    @declined_card = credit_card('4255555555555555')
    @invalid_cvc   = credit_card('4111111111160001', {verification_value: ''})
    @options = {
      description: 'Active Merchant',
      email: 'active.merchant@testing.test',
      currency: 'thb'
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:public_key], transcript)
  end

  def test_missing_secret_key
    assert_raise ArgumentError do
      OmiseGateway.new()
    end
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert_equal response.params['amount'], @amount
    assert response.params['paid'], 'paid should be true'
    assert response.params['authorized'], 'authorized should be true'
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @invalid_cvc)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_successful_purchase_after_store
    response = @gateway.store(@credit_card)
    response = @gateway.purchase(@amount, nil, { customer_id: response.authorization })
    assert_success response
    assert_equal response.params['amount'], @amount
  end

  def test_failed_purchase_with_token
    response = @gateway.purchase(@amount, nil, {token_id: 'tokn_invalid_12345'})
    assert_failure response
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.params['id'].match(/cust_test_[1-9a-z]+/)
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
  end

  def test_successful_unstore
    response = @gateway.store(@credit_card, @options)
    customer = @gateway.unstore(response.params['id'])
    assert customer.params['deleted']
  end

  def test_authorize
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize
    assert_equal authorize.params['amount'], @amount
    assert !authorize.params['paid'], 'paid should be false'
    assert authorize.params['authorized'], 'authorized should be true'
  end

  def test_authorize_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    capture   = @gateway.capture(@amount, authorize.authorization, @options)
    assert_success capture
    assert capture.params['paid'], 'paid should be true'
    assert capture.params['authorized'], 'authorized should be true'
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal purchase.params['amount'], @amount
    response = @gateway.refund(@amount-1000, purchase.authorization)
    assert_success response
    assert_equal @amount-1000, response.params['amount']
  end

end
