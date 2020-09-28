require 'test_helper'
require 'active_support/core_ext/hash/slice'

class RemoteTransactProTest < Test::Unit::TestCase
  def setup
    test_credentials = fixtures(:transact_pro).slice(:guid, :password, :terminal)
    test_card = fixtures(:transact_pro).slice(:card_number, :verification_value, :month, :year)

    @gateway = TransactProGateway.new(test_credentials)

    @amount = 100
    @credit_card = credit_card(test_card.delete(:card_number), test_card)
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: Time.now.to_i,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.authorization
    assert_equal 'Success', response.message
    assert response.test?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'Failed', response.message
    assert_equal '908', response.params['result_code']
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'Failed', response.message
    assert_equal '908', response.params['result_code']
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert_raise(ArgumentError) do
      @gateway.capture(@amount-1, auth.authorization)
    end
  end

  def test_failed_capture
    response = @gateway.capture(nil, 'bogus|100')
    assert_failure response
    assert_equal "bogus|100", response.authorization
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
    assert_equal 'Refund Success', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal 'Refund Success', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount+1, purchase.authorization)
    assert_failure refund
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Failed', response.message
  end

  def test_invalid_login
    gateway = TransactProGateway.new(
      guid: '',
      password: '',
      terminal: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{bad access data}, response.message
  end
end
