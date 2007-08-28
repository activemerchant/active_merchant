require File.dirname(__FILE__) + '/../test_helper'

# Some of the standard tests have been removed at Protx test
# server is pants and accepts anything and says Status=OK. (shift)
class RemoteProtxTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  # Run the tests in the simulated environment
  # set to false to run the tests in the test environment
  ProtxGateway.simulate = true
  
  LOGIN = 'X'
  
  AMOUNT = 100

  def setup
    @gateway = ProtxGateway.new(
      :login => LOGIN
    )
    
    @amex = CreditCard.new(
      :number => '374245455400001',
      :month => 12,
      :year => 2009,
      :verification_value => 4887,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :american_express
    )

    @maestro = CreditCard.new(
      :number => '6759016800000120097',
      :month => 6,
      :year => 2009,
      :issue_number => 1,
      :verification_value => 701,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :maestro
    )
    
    @solo = CreditCard.new(
      :number => '6334960300099354',
      :month => 6,
      :year => 2008,
      :issue_number => 1,
      :verification_value => 227,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :solo
    )

    @mastercard = CreditCard.new(
      :number => '5301250070000191',
      :month => 12,
      :year => 2009,
      :verification_value => 419,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :master
    )

    @declined_card = CreditCard.new(
      :number => '4000300011112220',
      :month => 9,
      :year => 2009,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )

    @mastercard_options = { 
      :address => { :address1 => '25 The Larches',
                    :city => "Narborough",
                    :state => "Leicester",
                    :zip => 'LE10 2RT'
                  },
      :order_id => generate_order_id,
      :description => 'Store purchase'
    }
   
    @maestro_options = {
      :address => { :address1 => 'The Parkway',
                    :address2 => "Larches Approach",
                    :city => "Hull",
                    :state => "North Humberside",
                    :zip => 'HU7 9OP'
                  },
      :order_id => generate_order_id,
      :description => 'Store purchase'
    }
    
    @solo_options = {
      :address => {
        :address1 => '5 Zigzag Road',
        :city => 'Isleworth',
        :state => 'Middlesex',
        :zip => 'TW7 8FF'
      },
      :order_id => generate_order_id,
      :description => 'Store purchase'
    }
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(AMOUNT, @mastercard, @mastercard_options)
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_successful_authorization_and_capture
    assert auth = @gateway.authorize(AMOUNT, @mastercard, @mastercard_options)
    assert auth.success?
    
    assert capture = @gateway.capture(AMOUNT, auth.authorization)
    assert capture.success?
  end
  
  def test_successful_authorization_and_void
    assert auth = @gateway.authorize(AMOUNT, @mastercard, @mastercard_options)
    assert auth.success?    
     
    assert void = @gateway.void(auth.authorization)
    assert void.success?
  end
  
  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(AMOUNT, @mastercard, @mastercard_options)
    assert purchase.success?    
     
    assert void = @gateway.void(purchase.authorization)
    assert void.success?
  end
  
  def test_successful_purchase_and_credit
    assert purchase = @gateway.purchase(AMOUNT, @mastercard, @mastercard_options)
    assert purchase.success?    
    
    assert credit = @gateway.credit(AMOUNT, purchase.authorization,
      :description => 'Crediting trx', 
      :order_id => generate_order_id
    )
    
    assert credit.success?
  end
  
  def test_successful_maestro_purchase
    assert response = @gateway.purchase(AMOUNT, @maestro, @maestro_options)
    assert response.success?
  end
  
  def test_successful_solo_purchase
    assert response = @gateway.purchase(AMOUNT, @solo, @solo_options)
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_successful_amex_purchase
    assert response = @gateway.purchase(AMOUNT, @amex, :order_id => generate_order_id)   
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_invalid_login
    message = ProtxGateway.simulate ? 'VSP Simulator cannot find your vendor name.  Ensure you have have supplied a Vendor field with your VSP Vendor name assigned to it.' : '3034 : The Vendor or VendorName value is required.' 
    
    gateway = ProtxGateway.new(
        :login => ''
    )
    assert response = gateway.purchase(AMOUNT, @mastercard, @mastercard_options)
    assert_equal message, response.message
    assert !response.success?
  end
end
