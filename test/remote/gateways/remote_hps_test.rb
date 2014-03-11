require 'test_helper'

class RemoteHpsTest < Test::Unit::TestCase
  def setup
    @gateway = HpsGateway.new(fixtures(:hps))

    @amount = 100
    @declined_amount = 10.34
    @credit_card =   credit_card('4000100011112224')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_details
    @options[:description] = 'Description'
    @options[:order_id] = '12345'
    @options[:customer_id] = '654321'

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card was declined.', response.message
  end

  def test_successful_authorize_with_details
    @options[:description] = 'Description'
    @options[:order_id] = '12345'
    @options[:customer_id] = '654321'

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
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
    assert_equal 'Success', refund.params['GatewayRspMsg']
    assert_equal '0', refund.params['GatewayRspCode']
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.params['GatewayRspMsg']
    assert_equal '0', refund.params['GatewayRspCode']
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
    assert_equal 'Success', void.params['GatewayRspMsg']
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
    assert_match %r{rejected}i, response.message
  end

  def test_empty_login
    gateway = HpsGateway.new(secret_api_key: '')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_nil_login
    gateway = HpsGateway.new(secret_api_key: nil)
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_invalid_login
    gateway = HpsGateway.new(secret_api_key: 'Bad_API_KEY')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Authentication error. Please double check your service configuration.', response.message
  end

  def test_successful_get_token_from_auth
    @options[:store] = true
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
  end

  def test_successful_get_token_from_purchase
    @options[:store] = true
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
  end

  def test_successful_purchase_with_token_from_auth
    @options[:store] = true
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Visa', response.params['CardType']
    assert_equal 'Success', response.params['TokenRspMsg']
    assert_not_nil response.params['TokenValue']
    token = response.params['TokenValue']

    @options[:store] = false
    purchase = @gateway.purchase(@amount, token, @options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end
end
