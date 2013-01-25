require 'test_helper'

class RemotePinTest < Test::Unit::TestCase
  def setup
    @gateway = PinGateway.new(fixtures(:pin))

    @amount = 100
    @credit_card = credit_card('5520000000000000')
    @declined_card = credit_card('4100000000000001')

    @options = {
      :email => 'roland@pin.net.au',
      :ip => '203.59.39.62',
      :order_id => '1',
      :billing_address => address,
      :description => "Store Purchase #{DateTime.now.to_i}"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_store_and_token_charge
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_not_nil response.authorization

    token = response.authorization

    assert response1 = @gateway.purchase(@amount, token, @options)
    assert_success response1

    assert response2 = @gateway.purchase(@amount, token, @options)
    assert_success response2
    assert_not_equal response1.authorization, response2.authorization
  end

  def test_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.authorization

    token = response.authorization

    assert response = @gateway.refund(@amount, token, @options)
    assert_success response
    assert_not_nil response.authorization
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.authorization

    token = response.authorization

    assert response = @gateway.refund(@amount, token.reverse, @options)
    assert_failure response
  end

  def test_invalid_login
    gateway = PinGateway.new(:api_key => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
