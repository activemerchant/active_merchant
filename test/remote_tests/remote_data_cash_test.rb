# Author::    MoneySpyder, www.moneyspyder.co.uk
require File.dirname(__FILE__) + '/../test_helper'

class RemoteDataCashTest < Test::Unit::TestCase
  CLIENT = ''      
  PASSWORD = ''
    
  def setup
    #gateway to connect to Datacash
    @gateway = DataCashGateway.new(
      :login => CLIENT,
      :password => PASSWORD,
      :test => true
    )
  
    @mastercard = CreditCard.new(
      :number => '5473000000000007',
      :month => 3,
      :year => 2010,              
      :first_name => 'Mark',      
      :last_name => 'McBride',
      :type => :master,
      :verification_value => '547'
    )
    
    @solo = CreditCard.new(
      :first_name => 'Cody',
      :last_name => 'Fauser',
      :number => '633499100000000004',
      :month => 3,
      :year => 2010,
      :type => :solo,
      :issue_number => 5,
      :start_month => 12,
      :start_year => 2006,
      :verification_value => 444
    )
    
    @address = { 
      :name     => 'Mark McBride',
      :address1 => 'Flat 12/3',
      :address2 => '45 Main Road',
      :city     => 'London',
      :state    => 'None',
      :country  => 'GBR',
      :zip      => 'A987AA',
      :phone    => '(555)555-5555'
    }
    
    @params = {
      :order_id => generate_order_id,
      :billing_address => @address
    }
  end
  
  # Testing that we can successfully make a purchase in a one step
  # operation
  def test_successful_purchase
    response = @gateway.purchase(198, @mastercard, @params)
    assert response.success?
    assert response.test?
  end
  
  #the amount is changed to £1.99 - the DC test server won't check the
  #address details - this is more a check on the passed ExtendedPolicy
  def test_successful_purchase_without_address_check
    response = @gateway.purchase(199, @mastercard, @params)
    assert response.success?
    assert response.test?
  end
  
  def test_successful_purchase_with_solo_card
    response = @gateway.purchase(198, @solo, @params)
    assert response.success?
    assert response.test?
  end
  
  # this card number won't check the address details - testing extended
  # policy
  def test_successful_purchase_without_address_check2
    @solo.number = '633499110000000003'
    
    response = @gateway.purchase(198, @solo, @params)
    assert response.success?
    assert response.test?
  end
  
  def test_invalid_verification_number
    @mastercard.verification_value = 123
    response = @gateway.purchase(198, @mastercard, @params)
    assert !response.success?
    assert response.test?
  end
  
  def test_invalid_expiry_month
    @mastercard.month = 13
    response = @gateway.purchase(198, @mastercard, @params)
    assert !response.success?
    assert response.test?
  end
  
  def test_invalid_expiry_year
    @mastercard.year = 1999
    response = @gateway.purchase(198, @mastercard, @params)
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    amount = 198
    
    authorization = @gateway.authorize(amount, @mastercard, @params)
    assert authorization.success?
    assert authorization.test?
    
    capture = @gateway.capture(amount, authorization.authorization, @params)
    assert capture.success?
    assert capture.test?
  end
  
  def test_unsuccessful_capture
    response = @gateway.capture(198, '1234', @params)
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization_and_void
    amount = 198
    
    authorization = @gateway.authorize(amount, @mastercard, @params)
    assert authorization.success?
    assert authorization.test?
    
    void = @gateway.void(authorization.authorization, @params)
    assert void.success?
    assert void.test?
  end
  
  def test_successfuly_purchase_and_void
    purchase = @gateway.purchase(198, @mastercard, @params)
    assert purchase.success?
    assert purchase.test?
    
    void = @gateway.void(purchase.authorization, @params)
    assert void.success?
    assert void.test?
  end
  
  def test_merchant_reference_that_is_too_short
    @params[:order_id] = rand(10000)
    response = @gateway.purchase(198, @mastercard, @params)
    assert response.success?
    assert response.test?
  end
  
  def test_merchant_reference_containing_invalid_characters
    @params[:order_id] = "##{rand(1000) + 1000}.1"
    response = @gateway.purchase(198, @mastercard, @params)
    assert response.success?
    assert response.test?
  end
end
