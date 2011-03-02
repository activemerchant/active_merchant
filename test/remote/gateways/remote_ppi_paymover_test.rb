require 'test_helper'

class RemotePpiPaymoverTest < Test::Unit::TestCase
  

  def setup
    @gateway = PpiPaymoverGateway.new(fixtures(:ppi_paymover))
    
    @amount = 100
    @credit_card = credit_card('4788250000028291')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => Array.new(9, '').collect{("0".."9").to_a[rand(10)]}.join,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Successful transaction: Test transaction response.', response.message
  end
  
  # def test_successful_purchase
  #   assert response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end
  # 
  # def test_unsuccessful_purchase
  #   assert response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  # end
  # 
  # def test_authorize_and_capture
  #   amount = @amount
  #   assert auth = @gateway.authorize(amount, @credit_card, @options)
  #   assert_success auth
  #   assert_equal 'Success', auth.message
  #   assert auth.authorization
  #   assert capture = @gateway.capture(amount, auth.authorization)
  #   assert_success capture
  # end
  # 
  # def test_failed_capture
  #   assert response = @gateway.capture(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  # end
  # 
  # def test_invalid_login
  #   gateway = PpiPaymoverGateway.new(
  #               :login => '',
  #               :password => ''
  #             )
  #   assert response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  # end
end
