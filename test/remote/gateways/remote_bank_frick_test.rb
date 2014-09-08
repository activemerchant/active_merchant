require 'test_helper'

class RemoteBankFrickTest < Test::Unit::TestCase
  def setup
    @gateway = BankFrickGateway.new(fixtures(:bank_frick))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4222222222222')

    @options = {
      order_id: Time.now.to_i, # avoid duplicates
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match %r{Transaction succeeded}, response.message
    assert response.authorization
  end

  def test_successful_purchase_with_minimal_options
    assert response = @gateway.purchase(@amount, @credit_card, {address: address})
    assert_success response
    assert response.test?
    assert_match %r{Transaction succeeded}, response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{account or user is blacklisted}, response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Transaction succeeded}, response.message
    assert response.authorization
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_match %r{Transaction succeeded}, capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'account or user is blacklisted', response.message
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

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{account or user is blacklisted}, response.message
  end

  def test_invalid_login
    gateway = BankFrickGateway.new(
      sender: '',
      channel: '',
      userid: '',
      userpwd: '',
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
