#
# In order for this test to pass, a valid store number and PEM file 
# are required. Unfortunately, with LinkPoint YOU CAN'T JUST USE ANY 
# OLD STORE NUMBER. Also, you can't just generate your own PEM file. 
# You'll need to use a special PEM file provided by LinkPoint. 
#
# Go to http://www.linkpoint.com/support/sup_teststore.asp to set up 
# a test account.  Once you receive your test account you can get your
# pem file by clicking the Support link on the navigation menu and then
# clicking the Download Center link.
#
# You will also want to change your test account's fraud settings
# while running these tests.  Click the admin link at the top of 
# LinkPoint Central.  Then click "set lockout times" under Fraud Settings
# You will want to set Duplicate lockout time to 0 so that you can run
# the tests more than once without triggering this fraud detection.

require File.dirname(__FILE__) + '/../test_helper'

ActiveMerchant::Billing::LinkpointGateway.pem_file = File.read( File.dirname(__FILE__) + '/../mycert.pem'  )

class LinkpointTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :test
    
    # You can also pass in the complete certificate as a string
    # with the :pem option
    # Signup for a test LinkPoint account and use the Store Number
    # as the login argument.
    @gateway = LinkpointGateway.new(
      :login => '1909597035'
    )
      
    # Test credit card numbers
    # American Express: 371111111111111
    # Discover: 6011-1111-1111-1111
    # JCB: 311111111111111
    # MasterCard: 5111-1111-1111-1111
    # MasterCard: 5419-8400-0000-0003
    # Visa: 4111-1111-1111-1111

    @creditcard = CreditCard.new(
      :number => '4111111111111111',
      :month => Time.now.month.to_s,
      :year => (Time.now + 1.year).year,
      :first_name => 'Captain',
      :last_name => 'Jack',
      :verification_value => '123'
    )
    
     @address = {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'ON',
        :zip => 'K2P2A6',
        :country => 'CA',
        :address2 => 'Apartment 1',
        :phone => '(555)555-5555'
      }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(1000, @creditcard, 
      :order_id => generate_order_id, 
      :address => @address
    )
  
    assert_equal Response, response.class
    assert_equal true, response.success?
    assert_equal "APPROVED", response.params["approved"]
  end
  
  def test_successful_authorization_and_capture
    assert authorization = @gateway.authorize(100, @creditcard,
      :order_id => generate_order_id,
      :address => @address
    )
    
    assert authorization.success?
    assert authorization.test?
    assert capture = @gateway.capture(100, authorization.authorization)
    assert capture.success?
    assert_equal 'ACCEPTED', capture.message
  end
  
  def test_successful_purchase_without_cvv2_code
    @creditcard.verification_value = nil
    
    assert response = @gateway.purchase(2400, @creditcard, 
      :order_id => generate_order_id,
      :address => @address
    )
    assert_equal Response, response.class
    assert_equal true, response.success?
    assert_equal "APPROVED", response.params["approved"]
    assert_equal 'NNN', response.params["avs"]
  end
  
  def test_successful_purchase_with_cvv2_code
    assert response = @gateway.purchase(2400, @creditcard, 
      :order_id => generate_order_id,
      :address => @address
    )
    assert_equal Response, response.class
    assert_equal true, response.success?
    assert_equal "APPROVED", response.params["approved"]
    assert_equal 'NNNM', response.params["avs"]
  end
  
  def test_successful_purchase_and_void
    purchase = @gateway.purchase(100, @creditcard,
      :order_id => generate_order_id,
      :address => @address
    )
    assert purchase.success?
    
    assert void = @gateway.void(purchase.authorization)
    assert void.success?
  end
  
  def test_successfull_purchase_and_credit
    assert purchase = @gateway.purchase(2400, @creditcard, 
      :order_id => generate_order_id,
      :address => @address
    )
    assert_equal true, purchase.success?
    
    assert credit = @gateway.credit(2400, purchase.authorization)
    assert credit.success?
  end

  
  def test_successful_recurring_payment
    assert response = @gateway.recurring(2400, @creditcard, 
      :order_id => generate_order_id, 
      :installments => 12,
      :startdate => "immediate",
      :periodicity => :monthly,
      :address => @address
    )
    
    assert_equal Response, response.class
    assert_equal true, response.success?
    assert_equal "APPROVED", response.params["approved"]
  end
  
  
  def test_declined_purchase_with_invalid_credit_card
    @creditcard.number = '1111111111111111'
    assert response = @gateway.purchase(100, @creditcard, 
      :order_id => generate_order_id,
      :address => @address
    )
    
    assert_equal Response, response.class
    assert_equal false, response.success?
    assert_equal "DECLINED", response.params["approved"]
  end
end
