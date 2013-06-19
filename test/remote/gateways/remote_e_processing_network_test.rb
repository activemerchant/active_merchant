require 'test_helper'

class RemoteEProcessingNetworkTest < Test::Unit::TestCase


  def setup
    @gateway = EProcessingNetworkGateway.new(fixtures(:e_processing_network))

    @amount = 100
    @declined_amount = 101
    @credit_card = credit_card('4000100011112224')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match /APPROVED \d+/, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_match /APPROVED \d+/, auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  end

  def test_invalid_login
    gateway = EProcessingNetworkGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Authentication', response.message
  end
end
