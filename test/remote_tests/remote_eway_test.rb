require File.dirname(__FILE__) + '/../test_helper'

class EwayTest < Test::Unit::TestCase
  def setup
    @gateway = EwayGateway.new(
      :login => '87654321'
    )

    @creditcard_success = CreditCard.new(
      :number => '4646464646464646',
      :month => (Time.now.month + 1),
      :year => (Time.now.year + 1),
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :verification_value => '123'
    )
    
    @creditcard_fail = CreditCard.new(
      :number => '1234567812345678',
      :month => (Time.now.month),
      :year => (Time.now.year),
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
    
    @params = {
      :order_id => '1230123',
      :email => 'bob@testbob.com',
      :address => { :address1 => '47 Bobway, Bobville, WA, Australia',
                    :zip => '2000'
                  } ,
      :description => 'purchased items'
    }
  end
  
  def test_invalid_amount
    assert response = @gateway.purchase(101, @creditcard_success, @params)
    assert !response.success?
    assert_equal 'A8,INVALID AMOUNT', response.params['ewaytrxnerror']
    assert_equal "Amount is invalid", response.message
  end
   
  def test_purchase_success_with_verification_value 
    assert response = @gateway.purchase(100, @creditcard_success, @params)
    assert_instance_of Response, response
    assert_equal '123456', response.authorization
    assert response.success?
    assert_equal '00,TRANSACTION APPROVED', response.params['ewaytrxnerror']
    assert_equal "Transaction was successfully processed", response.message
  end

  def test_invalid_expiration_date
    @creditcard_success.year = 2005 
    assert response = @gateway.purchase(100, @creditcard_success, @params)
    assert !response.success?
    assert_match 'AB,INVALID EXPIRY', response.params['ewaytrxnerror']
    assert_equal "Card expiry date is invalid", response.message
  end
  
  def test_purchase_with_invalid_verification_value
    @creditcard_success.verification_value = '000' 
    assert response = @gateway.purchase(100, @creditcard_success, @params)
    assert_instance_of Response, response
    assert_nil response.authorization
    assert !response.success?
    assert_equal '01,CONTACT YOUR BANK. Data Sent:4646464646464646:000', response.params['ewaytrxnerror']
    assert_equal "Card verification number didn't match", response.message
  end

  def test_purchase_success_without_verification_value
    @creditcard_success.verification_value = nil 
    assert response = @gateway.purchase(100, @creditcard_success, @params)
    assert_instance_of Response, response
    assert_equal '123456', response.authorization
    assert response.success?
    assert_equal '00, TRANSACTION APPROVED', response.params['ewaytrxnerror']
    assert_equal "Transaction was successfully processed", response.message
  end

  def test_purchase_error
    assert response = @gateway.purchase(100, @creditcard_fail, @params)
    assert_instance_of Response, response
    assert_nil response.authorization
    assert_equal false, response.success?
    assert_equal "A9,INVALID CARD NUMBER. Data Sent:1234567812345678", response.params['ewaytrxnerror']
    assert_equal "Card number is invalid", response.message
  end
end
