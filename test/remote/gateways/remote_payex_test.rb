require 'test_helper'

class RemotePayexTest < Test::Unit::TestCase

  def setup
    @gateway = PayexGateway.new(fixtures(:payex))

    @amount = 1
    # cvv 210, expire date 02/14
    @credit_card = credit_card('4581090329655682')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1',
      # :billing_address => address,
      :description => 'Store Purchase',
      :client_ip_address => '1.2.3.4',
      :order_id => '1234',
      :product_number => '4321'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end

  # def test_invalid_login
  #   gateway = PayexGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
