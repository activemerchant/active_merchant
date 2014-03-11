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

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card was declined.', response.message
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

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_invalid_login
    gateway = HpsGateway.new(
      secret_api_key: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card,@options)
    assert_success response
  end

  def test_successful_get_token_from_verify
    @options[:request_multi_use_token] = true
    response = @gateway.verify(@credit_card,@options)

    assert_success response
    assert_equal  'Success', response.params['token_data'].response_message
    assert_not_nil response.params['token_data'].token_value
  end

  def test_successful_get_token_from_auth
    @options[:request_multi_use_token] = true
    response = @gateway.authorize(@amount,@credit_card,@options)

    assert_success response
    assert_equal  'Success', response.params['token_data'].response_message
    assert_not_nil response.params['token_data'].token_value
  end

  def test_successful_get_token_from_purchase
    @options[:request_multi_use_token] = true
    response = @gateway.purchase(@amount,@credit_card,@options)

    assert_success response
    assert_equal  'Success', response.params['token_data'].response_message
    assert_not_nil response.params['token_data'].token_value
  end

  def test_successful_purchase_with_token_from_auth
    @options[:request_multi_use_token] = true
    response = @gateway.authorize(@amount,@credit_card,@options)

    assert_success response
    assert_equal  'Success', response.params['token_data'].response_message
    assert_not_nil response.params['token_data'].token_value
    token = response.params['token_data'].token_value

    @options[:request_multi_use_token] = false
    purchase = @gateway.purchase(@amount,token,@options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end

  def test_successful_purchase_with_token_from_verify
    @options[:request_multi_use_token] = true
    response = @gateway.verify(@credit_card,@options)

    assert_success response
    assert_equal  'Success', response.params['token_data'].response_message
    assert_not_nil response.params['token_data'].token_value
    token = response.params['token_data'].token_value

    @options[:request_multi_use_token] = false
    purchase = @gateway.purchase(@amount,token,@options)
    assert_success purchase
    assert_equal 'Success', purchase.message
  end
end
