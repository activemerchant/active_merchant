require 'test_helper'
#require File.join(File.dirname(__FILE__), '../../test_helper')

class RemoteLucyTest < Test::Unit::TestCase
  

  def setup
    @gateway = LucyGateway.new(fixtures(:lucy_approve))
    
    @credit_card = ::ActiveMerchant::Billing::CreditCard.new({
                  :number => '4005551155111114',
                  :month => 10,
                  :year => Time.now.year + 1,
                  :first_name => 'John',
                  :last_name => 'Doe'
                })
    
    @amount = 100
    #@credit_card = credit_card('4000100011112224')
    #@declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    @amount = 101 #$xx.01 errors
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Decline', response.message
    assert_failure response
  end
  
  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Invalid Expiration Date', response.message
    assert_failure response
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
  end



  #def test_authorize_and_capture
  #  amount = @amount
  #  assert auth = @gateway.authorize(amount, @credit_card, @options)
  #  assert_success auth
  #  assert_equal 'Success', auth.message
  #  assert auth.authorization
  #  assert capture = @gateway.capture(amount, auth.authorization)
  #  assert_success capture
  #end

  #def test_failed_capture
  #  assert response = @gateway.capture(@amount, '')
  #  assert_failure response
  #  assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
  #end

  #def test_invalid_login
  #  gateway = LucyGateway.new(
  #              :login => '',
  #              :password => ''
  #            )
  #  assert response = gateway.purchase(@amount, @credit_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  #end
end
