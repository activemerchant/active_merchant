require File.dirname(__FILE__) + '/../test_helper'

class RemotePaymentExpressTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  LOGIN = 'LOGIN'
  PASSWORD = 'PASSWORD'

  def setup
    @gateway = PaymentExpressGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )
    
    @creditcard = CreditCard.new(
      :number => '5105105105105100',
      :month => 11,
      :year => 2009,
      :first_name => 'Cody',
      :last_name => 'Fauser',
      :verification_value => '000',
      :type => 'master'
    )

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
     :email => 'cody@example.com'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(Money.new(100, 'NZD'), @creditcard, @options)
    assert_equal "APPROVED", response.message
    assert response.success?
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_declined_purchase
    assert response = @gateway.purchase(Money.new(100, 'NZD'), @creditcard, @options)
    assert_equal '', response.message
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(Money.new(100, 'NZD'), @creditcard, @options)
    assert_equal "APPROVED", response.message
    assert response.success?
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    amount = Money.new(100, 'NZD')
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert auth.success?
    assert_equal 'APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
  end
  
  def test_failed_capture
    assert response = @gateway.capture(Money.new(100, 'NZD'), '999')
    assert !response.success?
    assert_equal '', response.message
  end
  
  def test_invalid_login
    gateway = PaymentExpressGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(Money.new(100, 'NZD'), @creditcard, @options)
    assert_equal 'Invalid Credentials', response.message
    assert !response.success?
  end
end
