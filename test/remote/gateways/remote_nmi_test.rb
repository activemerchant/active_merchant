require 'test_helper'

class RemoteNmiTest < Test::Unit::TestCase
  def setup
    @gateway = NmiGateway.new(fixtures(:nmi))
    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_forced_test_mode_purchase
    gateway = NmiGateway.new(fixtures(:nmi).update(:test => true))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert response.authorization
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end

  def test_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.refund(@amount, response.authorization, :card_number => @credit_card.number)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_bad_login
    gateway = NmiGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    assert response = gateway.purchase(@amount, @credit_card)
    assert_equal Response, response.class
    assert_match(/Authentication Failed/, response.message)
    assert_equal false, response.success?
  end

end
