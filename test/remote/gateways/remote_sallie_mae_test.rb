require File.dirname(__FILE__) + '/../../test_helper'

class RemoteSallieMaeTest < Test::Unit::TestCase
  

  def setup
    @gateway = SallieMaeGateway.new(fixtures(:sallie_mae))
    
    @amount = 100
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  # def test_a
  #   response = @gateway.authorize(@amount, @credit_card, @options)
  #   p response
  #   response = @gateway.capture(@amount, @credit_card, response.authorization, @options)
  #   p response
  #   #response = @gateway.purchase(@amount, @credit_card, @options)
  # end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Cvv2 mismatch', response.message
  end

  def test_authorize_and_capture
    amount = (@amount * rand).to_i
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message
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
  #   gateway = SallieMaeGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
