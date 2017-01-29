require 'test_helper'

class RemoteClearhausTest < Test::Unit::TestCase
  def setup
    @gateway = ClearhausGateway.new(fixtures(:clearhaus))

    @amount = 100
    @credit_card   = credit_card('4111111111111111')
    @declined_card = credit_card('4200000000000000')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_signing_request
    gateway = ClearhausGateway.new(fixtures(:clearhaus_secure))

    assert gateway.options[:private_key]
    assert auth = gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
  end

  def test_cleans_whitespace_from_private_key
    credentials = fixtures(:clearhaus_secure)
    credentials[:private_key] = "     #{credentials[:private_key]}     "
    gateway = ClearhausGateway.new(credentials)

    assert gateway.options[:private_key]
    assert auth = gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
  end

  def test_unsuccessful_signing_request
    credentials = fixtures(:clearhaus_secure)
    credentials[:private_key] = "foo"
    gateway = ClearhausGateway.new(credentials)

    assert gateway.options[:private_key]
    assert auth = gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_equal "Neither PUB key nor PRIV key: not enough data", auth.message

    credentials = fixtures(:clearhaus_secure)
    credentials[:signing_key] = "foo"
    gateway = ClearhausGateway.new(credentials)

    assert gateway.options[:signing_key]
    assert auth = gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert_equal "invalid signing api-key", auth.message
  end

  def test_successful_purchase_without_cvv
    gateway = ClearhausGateway.new(fixtures(:clearhaus_secure))
    credit_card = credit_card('4111111111111111', verification_value: nil)
    response = gateway.purchase(@amount, credit_card, @options)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_text_on_statement
    options = { text_on_statement: "hello" }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_equal response.params["text_on_statement"], "hello"
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid card number', response.message
    assert_equal 40110, response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'ABC'))
    assert_failure response
    assert_equal 'invalid currency', response.message
    assert_equal 40140, response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'invalid transaction id', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '123')
    assert_failure response
    assert_equal 'invalid transaction id', response.message
  end

  def test_successful_refund_of_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
    assert_equal 'Approved', refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
    assert_equal 'invalid transaction id', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Approved', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Invalid card number}, response.message
  end

  def test_successful_authorize_with_nonfractional_currency
    assert response = @gateway.authorize(100, @credit_card, @options.merge(:currency => 'KRW'))
    assert_equal 1, response.params['amount']
    assert_success response
  end

  def test_invalid_login
    gateway = ClearhausGateway.new(api_key: 'test')

    assert_raise ActiveMerchant::ResponseError do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end
end
