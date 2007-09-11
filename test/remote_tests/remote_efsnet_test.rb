require File.dirname(__FILE__) + '/../test_helper'

class RemoteEfsnetTest < Test::Unit::TestCase
  AMOUNT = 100
  DECLINED_AMOUNT = 156

  def setup
    Base.gateway_mode = :test

    @gateway = EfsnetGateway.new(fixtures(:efsnet))
    
    @creditcard = credit_card('4000100011112224')

    @options = { :order_id => 0, 
                 :address => { :address1 => '1234 Shady Brook Lane',
                               :zip => '90210'
                             }
               }
  end
  
  def test_successful_purchase
    @options[:order_id] += 1
    assert response = @gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal 'Approved', response.message
    assert response.success?
    assert response.test?
  end

  def test_successful_force
    @options[:order_id] += 1
    assert response = @gateway.force(AMOUNT, '123456', @creditcard, @options)
    assert_equal 'Approved', response.message
    assert response.success?
  end

  def test_successful_voice_authorize
    @options[:order_id] += 1
    assert response = @gateway.voice_authorize(AMOUNT, '123456', @creditcard, @options)
    assert_equal 'Accepted', response.message
    assert response.success?
  end

  def test_unsuccessful_purchase
    @options[:order_id] += 1
    assert response = @gateway.purchase(DECLINED_AMOUNT, @creditcard, @options)
    assert_equal 'Declined', response.message
    assert !response.success?
  end

  def test_authorize_and_capture
    @options[:order_id] += 1
    
    amount = AMOUNT
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert auth.success?    
    assert_equal 'Approved', auth.message
    assert auth.authorization
    
    @options[:order_id] += 1
    assert capture = @gateway.capture(amount, auth.authorization, @options)
    assert capture.success?
  end

  def test_purchase_and_void
    @options[:order_id] += 1
    amount = AMOUNT
    assert purchase = @gateway.purchase(amount, @creditcard, @options)
    assert purchase.success?
    assert_equal 'Approved', purchase.message
    assert purchase.authorization
    @options[:order_id] += 1
    assert void = @gateway.void(purchase.authorization, @options)
    assert void.success?
  end

  def test_failed_capture
    @options[:order_id] += 1
    assert response = @gateway.capture(AMOUNT, '1;1', @options)
    assert !response.success?
    assert_equal 'Bad original transaction', response.message
  end

  def test_invalid_login
    @options[:order_id] += 1
    gateway = EfsnetGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(AMOUNT, @creditcard, @options)
    assert_equal 'Invalid credentials', response.message
    assert !response.success?
  end
end
