require 'test_helper'
#require File.join(File.dirname(__FILE__), '../../test_helper')

class RemoteMaxxTest < Test::Unit::TestCase
  

  def setup
    @gateway = MaxxGateway.new(fixtures(:maxx))
    
    @credit_card = ::ActiveMerchant::Billing::CreditCard.new({
                  :number => '4005551155111114',
                  :month => 10,
                  :year => Time.now.year + 1,
                  :first_name => 'John',
                  :last_name => 'Doe'
                })
    @credit_card_present = ::ActiveMerchant::Billing::CreditCard.new({
                  :number => '371449635398431',
                  :month => 10,
                  :year => Time.now.year + 1,
                  :first_name => 'John',
                  :last_name => 'Doe',
                  :track2 => "371449635398431=#{Time.now.year+1}101015432112345678"
                })
    
    @expired_credit_card_present = ::ActiveMerchant::Billing::CreditCard.new({
                  :number => '371449635398431',
                  :month => 10,
                  :year => 2009,
                  :first_name => 'John',
                  :last_name => 'Doe',
                  :track2 => '371449635398431=09101015432112345678'
                })
    
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end
  
  def test_successful_purchase_with_card_present
    assert response = @gateway.purchase(200, @credit_card_present, @options)
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
  
  def test_expired_credit_card_with_card_present
    #@credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @expired_credit_card_present, @options)
    assert_equal 'Invalid Expiration Date', response.message
    assert_failure response
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Approved', response.message
    assert_success response
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(300, @credit_card, @options)
    assert_success authorization
    assert_equal 'Approved', authorization.message
  
    assert authorization.authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'Approved', capture.message
  end  
  
  def test_authorization_and_void
    assert authorization = @gateway.purchase(400, @credit_card, @options)
    assert_success authorization
    assert_equal 'Approved', authorization.message
  
    assert authorization.authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Approved', void.message
  end  
  
  def test_invalid_login
    gateway = MaxxGateway.new(
                :login => 'x',
                :password => 'y'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Login', response.message
  end

  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '123456')
    assert_failure response
    assert_equal 'Capture Error', response.message
  end

end
