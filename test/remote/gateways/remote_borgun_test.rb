require 'test_helper'

class RemoteBorgunTest < Test::Unit::TestCase
  def setup
    # Borgun's test server has an improperly installed cert
    BorgunGateway.ssl_strict = false

    @gateway = BorgunGateway.new(fixtures(:borgun))

    @amount = 100
    @credit_card = credit_card('5587402000012011', year: 2018, month: 9, verification_value: 415)
    @declined_card = credit_card('4155520000000002')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def teardown
    BorgunGateway.ssl_strict = true
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_usd
    response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: "USD"))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_without_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Error with ActionCode=121', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_usd
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, currency: 'USD')
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_successful_refund_usd
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, currency: 'USD')
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_void_with_no_currency_in_authorization
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    *new_auth, _ = auth.authorization.split("|")
    assert void = @gateway.void(new_auth.join("|"))
    assert_success void
  end

  def test_successful_void_usd
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_void_usd_with_options
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options.merge(currency: 'USD'))
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  # This test does not consistently pass. When run multiple times within 1 minute,
  # an ActiveMerchant::ConnectionError(<The remote server reset the connection>)
  # exception is raised.
  def test_invalid_login
    gateway = BorgunGateway.new(
      processor: '0',
      merchant_id: '0',
      username: 'not',
      password: 'right'
    )
    authentication_exception = assert_raise ActiveMerchant::ResponseError, 'Failed with 401 [ISS.0084.9001] Invalid credentials' do
      gateway.purchase(@amount, @credit_card, @options)
    end
    assert response = authentication_exception.response
    assert_match(/Access Denied/, response.body)
  end
end
