require File.dirname(__FILE__) + '/../test_helper'

class RemoteQuickpayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  # Quickpay MerchantId
  LOGIN = 'MERCHANTID'
  
  # Quickpay md5checkword
  PASSWORD = 'CHECKWORD'
  
  def setup
  
    @gateway = QuickpayGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )

    @creditcard = CreditCard.new(
      :number => '4000100011112224',
      :month => 9,
      :year => 2009,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '123'
    )

    @declined_card = CreditCard.new(
      :number => '4000300011112220',
      :month => 9,
      :year => 2009,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(Money.new(100), @creditcard, :order_id => generate_order_id)
    assert_equal 'OK', response.message
    assert response.success?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_purchase_with_missing_cvv2
    assert response = @gateway.purchase(Money.new(100), @declined_card, :order_id => generate_order_id)
    assert_equal 'Missing/error in card verification data', response.message
    assert !response.success?
    assert response.authorization.blank?
  end

  def test_authorize_and_capture
    amount = Money.new(100)
    assert auth = @gateway.authorize(amount, @creditcard, :order_id => generate_order_id)
    assert auth.success?
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
    assert_equal 'OK', capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(Money.new(100), '')
    assert !response.success?
    assert_equal 'Missing/error in transaction number', response.message
  end
  
  def test_purchase_and_void
    amount = Money.new(100)
    assert auth = @gateway.authorize(amount, @creditcard, :order_id => generate_order_id)
    assert auth.success?
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert void.success?
    assert_equal 'OK', void.message
  end
  
  def test_authorization_capture_and_credit
    amount = Money.new(100)
    assert auth = @gateway.authorize(amount, @creditcard, :order_id => generate_order_id)
    assert auth.success?
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
    assert credit = @gateway.credit(Money.new(100), auth.authorization)
    assert credit.success?
    assert_equal 'OK', credit.message
  end
  
  def test_purchase_and_credit
    amount = Money.new(100)
    assert purchase = @gateway.purchase(amount, @creditcard, :order_id => generate_order_id)
    assert purchase.success?
    assert credit = @gateway.credit(Money.new(100), purchase.authorization)
    assert credit.success?
  end

  def test_invalid_login
    gateway = QuickpayGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(Money.new(100), @creditcard, :order_id => generate_order_id)
    assert_equal 'Missing/error in merchant', response.message
    assert !response.success?
  end
end
