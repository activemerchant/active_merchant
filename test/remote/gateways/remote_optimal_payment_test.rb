require 'test_helper'

class RemoteOptimalPaymentTest < Test::Unit::TestCase
  def setup
    @gateway = OptimalPaymentGateway.new(fixtures(:optimal_payment))

    @amount = 100
    @declined_amount = 5
    @credit_card = credit_card('4387751111011')
    @expired_card = credit_card('4387751111011', month: 12, year: 2019)

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Basic Subscription',
      email: 'email@example.com',
      ip: '1.2.3.4'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_unsuccessful_purchase_with_shipping_address
    @options[:shipping_address] = address
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_successful_great_britain
    @options[:billing_address][:country] = 'GB'
    @options[:billing_address][:state] = 'North West England'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'auth declined', response.message
  end

  def test_purchase_with_no_cvv
    @credit_card.verification_value = ''
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_stored_data_auth_and_capture_after_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message

    assert auth = @gateway.stored_authorize(@amount, response.authorization)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_stored_data_purchase_after_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message

    assert stored_purchase = @gateway.stored_purchase(@amount, response.authorization)
    assert_success stored_purchase
  end

  def test_stored_data_auth_after_failed_store
    response = @gateway.store(@expired_card, @options)
    assert_failure response
    assert_not_nil response.authorization
    assert_equal 'ERROR', response.params['decision']

    assert auth = @gateway.stored_authorize(@amount, response.authorization)
    assert_failure auth
    assert_equal 'ERROR', auth.params['decision']
  end

  def test_stored_data_purchase_after_failed_store
    response = @gateway.store(@expired_card, @options)
    assert_failure response
    assert_not_nil response.authorization
    assert_equal 'ERROR', response.params['decision']

    assert stored_purchase = @gateway.stored_purchase(@amount, response.authorization)
    assert_failure stored_purchase
    assert_equal 'ERROR', stored_purchase.params['decision']
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_invalid_capture
    assert response = @gateway.capture(@amount, 'notgood')
    assert_failure response
    assert_equal 'Invalid authorization id', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_equal 'Authorization transaction not found', response.message
  end

  def test_stored_data_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert stored_purchase = @gateway.stored_purchase(@amount, response.authorization)
    assert_success stored_purchase
  end

  def test_overloaded_stored_data_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert stored_purchase = @gateway.purchase(@amount, response.authorization)
    assert_success stored_purchase
  end

  def test_stored_data_authorize_and_capture
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert auth = @gateway.stored_authorize(@amount, response.authorization)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_overloaded_stored_data_authorize_and_capture
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert auth = @gateway.authorize(@amount, response.authorization)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_invalid_login
    gateway = OptimalPaymentGateway.new(
      account_number: '1',
      store_id: 'bad',
      password: 'bad'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'invalid merchant account', response.message
  end

  # Password assertion hard-coded due to the value being the same as the login, which would cause a false-positive
  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed('%3CstorePwd%3Etest%3C/storePwd%3E', transcript)
  end
end
