require File.dirname(__FILE__) + '/../test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    @gateway = TrustCommerceGateway.new(
      :login => 'TestMerchant',
      :password => 'password'
    )

    @creditcard = credit_card('4111111111111111')
    
    @valid_verification_value = '123'
    @invalid_verification_value = '1234'
    
    @valid_address = {:address1 => '123 Test St.', :address2 => nil, :city => 'Somewhere', :state => 'CA', :zip => '90001'}
    @invalid_address = {:address1 => '187 Apple Tree Lane.', :address2 => nil, :city => 'Woodside', :state => 'CA', :zip => '94062'}
  end
  
  def test_bad_login
    @gateway.options[:login] = 'X'
    assert response = @gateway.purchase(100, @creditcard)
        
    assert_equal Response, response.class
    assert_equal ["error",
                  "offenders",
                  "status"], response.params.keys.sort

    assert_match /A field was improperly formatted, such as non-digit characters in a number field/, response.message
    
    assert_equal false, response.success?
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @creditcard)
        
    assert_equal Response, response.class  
    assert_match /The transaction was successful/, response.message
    
    assert_equal true, response.success?
    assert !response.authorization.blank?
  end
  
  def test_unsuccessful_purchase_with_invalid_cvv
    @creditcard.verification_value = @invalid_verification_value
    assert response = @gateway.purchase(100, @creditcard)
        
    assert_equal Response, response.class
    assert_match /CVV failed; the number provided is not the correct verification number for the card/, response.message
    assert_equal false, response.success?
  end
  
  def test_successful_purchase_with_avs
    assert response = @gateway.purchase(100, @creditcard, :address => @valid_address)
    assert_equal 'Y', response.params["avs"]
    assert_match /The transaction was successful/, response.message
    
    assert_equal true, response.success?
    assert !response.authorization.blank?
  end
  
  def test_purchase_with_avs_for_invalid_address
    assert response = @gateway.purchase(100, @creditcard, :address => @invalid_address)
    assert_equal "N", response.params["avs"]
    assert_match /The transaction was successful/, response.message
    assert response.success?
  end
  
  def test_successful_authorize
    @creditcard.verification_value = @valid_verification_value
    assert response = @gateway.authorize(100, @creditcard)
    assert_match /The transaction was successful/, response.message
    assert_equal true, response.success?
    assert !response.authorization.blank?
  end
  
  def test_unsuccessful_authorize_with_invalid_cvv
    @creditcard.verification_value = @invalid_verification_value
    assert response = @gateway.authorize(100, @creditcard)
    assert_match /CVV failed; the number provided is not the correct verification number for the card/, response.message
    assert_equal false, response.success?
  end
    
  def test_successful_authorize_with_avs
    assert response = @gateway.authorize(100, @creditcard, {:address => @valid_address})
    
    assert_equal "Y", response.params["avs"]
    assert_match /The transaction was successful/, response.message

    assert_equal true, response.success?
    assert !response.authorization.blank?
  end
  
  def test_authorization_with_avs_for_invalid_address
    assert response = @gateway.authorize(100, @creditcard, {:address => @invalid_address})
    assert_equal "N", response.params["avs"]
    assert_match /The transaction was successful/, response.message
    assert response.success?
  end
  
  def test_successful_capture
    auth = @gateway.authorize(300, @creditcard)
    assert auth.success?
    response = @gateway.capture(300, auth.authorization)
    
    assert response.success?
    assert_equal 'The transaction was successful', response.message 
    assert_equal 'accepted', response.params['status']
    assert response.params['transid']
  end
  
  def test_successful_credit
    assert response = @gateway.credit(100, '011-0022698151')
    
    assert_match /The transaction was successful/, response.message
    assert response.success?    
  end
  
  def test_store_failure
    assert response = @gateway.store(@creditcard)
        
    assert_equal Response, response.class
    assert_match /The merchant can't accept data passed in this field/, response.message    
    assert !response.success?   
  end
  
  def test_unstore_failure
    assert response = @gateway.unstore('testme')

    assert_match /The merchant can't accept data passed in this field/, response.message    
    assert_equal false, response.success?   
  end
  
  def test_recurring_failure
    assert response = @gateway.recurring(100, @creditcard, :periodicity => :weekly)

    assert_match /The merchant can't accept data passed in this field/, response.message    
    assert_equal false, response.success?   
  end
end