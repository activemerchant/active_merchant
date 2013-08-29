require 'test_helper'

class RemoteSoEasyPayTest < Test::Unit::TestCase


  def setup
    @gateway = SoEasyPayGateway.new(fixtures(:so_easy_pay))

    @amount = 100
    @credit_card = credit_card('4111111111111111', {:verification_value => '000', :month => '12', :year => '2015'})
    @declined_card = credit_card('4000300011112220')

    @options = {
      :currency => 'EUR',
      :ip => '192.168.19.123',
      :email => 'test@blaha.com',
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction successful', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
  end

  def test_invalid_login
    gateway = SoEasyPayGateway.new(
                :login => 'one',
                :password => 'wrong'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Website verification failed, wrong websiteID or password', response.message
  end
end

