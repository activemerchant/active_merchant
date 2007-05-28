require File.dirname(__FILE__) + '/../test_helper'

class RemotePaymentExpressTest < Test::Unit::TestCase
  LOGIN = 'LOGIN'
  PASSWORD = 'PASSWORD'
  
  def setup
    @gateway = PaymentExpressGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )
    
    @creditcard = credit_card('4111111111111111')

    @options = { 
      :address => { 
        :name => 'Cody Fauser',
        :address1 => '1234 Shady Brook Lane',
        :city => 'Ottawa',
        :state => 'ON',
        :country => 'CA',
        :zip => '90210',
        :phone => '555-555-5555'
      },
     :email => 'cody@example.com',
     :description => 'Store purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @creditcard, @options)
    assert_equal "APPROVED", response.message
    assert response.success?
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_successful_purchase_with_reference_id
    @options[:order_id] = rand(100000)
    assert response = @gateway.purchase(100, @creditcard, @options)
    assert_equal "APPROVED", response.message
    assert response.success?
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_declined_purchase
    assert response = @gateway.purchase(176, @creditcard, @options)
    assert_equal 'DECLINED', response.message
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal "APPROVED", response.message
    assert response.success?
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    amount = 100
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert auth.success?
    assert_equal 'APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
  end
  
  def test_purchase_and_credit
    amount = 10000
    assert purchase = @gateway.purchase(amount, @creditcard, @options)
    assert purchase.success?
    assert_equal 'APPROVED', purchase.message
    assert !purchase.authorization.blank?
    assert credit = @gateway.credit(amount, purchase.authorization, :description => "Giving a refund")
    assert credit.success?
  end
  
  def test_failed_capture
    assert response = @gateway.capture(100, '999')
    assert !response.success?
    assert_equal 'IVL DPSTXNREF', response.message
  end
  
  def test_invalid_login
    gateway = PaymentExpressGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(100, @creditcard, @options)
    assert_equal 'Invalid Credentials', response.message
    assert !response.success?
  end
  
  def test_store_credit_card
    assert response = @gateway.store(@creditcard)
    assert response.success?
    assert_equal "APPROVED", response.message
    assert !response.token.blank?
    assert_not_nil response.token
  end
  
  def test_store_with_custom_token
    token = Time.now.to_i.to_s #hehe
    assert response = @gateway.store(@creditcard, :billing_id => token)
    assert response.success?
    assert_equal "APPROVED", response.message
    assert !response.token.blank?
    assert_not_nil response.token
    assert_equal token, response.token
  end
  
  def test_store_invalid_credit_card
    original_number = @creditcard.number
    @creditcard.number = 2
  
    assert response = @gateway.store(@creditcard)
    assert !response.success?
  ensure
    @creditcard.number = original_number
  end
  
  def test_store_and_charge
    assert response = @gateway.store(@creditcard)
    assert response.success?
    assert_equal "APPROVED", response.message
    assert (token = response.token)
    
    assert purchase = @gateway.purchase( 100, token)
    assert_equal "APPROVED", purchase.message
    assert purchase.success?
    assert_not_nil purchase.authorization
  end  
  
  
end
