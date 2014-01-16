require 'test_helper'

class RemoteMaxipagoTest < Test::Unit::TestCase


  def setup
    @gateway = MaxipagoGateway.new(fixtures(:maxipago))

    @amount = 1000
    @invalid_amount = 2009
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4111111111111111', year: Time.now.year - 1)

    @options = {
      order_id: '12345',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_prepaid_voucher
    @options[:payment_id] = '1234567890'
    @options[:billing_address][:country] = 'BR'
    @options[:billing_address][:zip] = '22930-020'
    assert response = @gateway.prepaid_voucher(@amount, @options)
    assert_success response
    assert_equal 'ISSUED', response.message
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal 'INVALID REQUEST', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert_equal 'AUTHORIZED', response.message
    assert response.authorization
    assert capture = @gateway.capture(amount, response.authorization, @options)
    assert_success capture
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CAPTURED', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@invalid_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  #def test_failed_capture
  #  assert response = @gateway.capture(@amount, '')
  #  assert_failure response
  #  assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  #end

  #def test_invalid_login
  #  gateway = MaxipagoGateway.new(
  #              :login => '',
  #              :password => ''
  #            )
  #  assert response = gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  #end
end
