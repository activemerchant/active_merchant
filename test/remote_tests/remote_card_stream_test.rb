# Portions of the Cardstream gateway by Jonah Fox and Thomas Nichols
require File.dirname(__FILE__) + '/../test_helper'

class RemoteCardStreamTest < Test::Unit::TestCase
  LOGIN = 'X'
  PASSWORD = 'Y'

  def setup
    @gateway = CardStreamGateway.new(
      :login => LOGIN,
      :password => PASSWORD
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
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', response.message
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_declined_mastercard_purchase
    assert response = @gateway.purchase(10000, @mastercard, @mastercard_options)
    assert_equal 'CARD DECLINED', response.message
    assert !response.success?
    assert response.test?
  end
  
  def test_expired_mastercard
    @mastercard.year = 2005
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'CARD EXPIRED', response.message
    assert !response.success?
    assert response.test?
  end

  def test_successful_maestro_purchase
    assert response = @gateway.purchase(100, @maestro, @maestro_options)
    assert_equal 'APPROVED', response.message
    assert response.success?
  end
  
  def test_successful_solo_purchase
    assert response = @gateway.purchase(100, @solo, @solo_options)
    assert_equal 'APPROVED', response.message
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_successful_amex_purchase
    assert response = @gateway.purchase(100, @amex, :order_id => generate_order_id)
    assert_equal 'APPROVED', response.message
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_maestro_missing_start_date_and_issue_date
    @maestro.issue_number = nil
    assert response = @gateway.purchase(100, @maestro, @maestro_options)
    assert_equal 'ISSUE NUMBER MISSING', response.message
    assert !response.success?
    assert response.test?
  end
  
  def test_invalid_login
    gateway = CardStreamGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'Merchant ID or Password Error', response.message
    assert !response.success?
  end
  
  def test_unsupported_merchant_currency
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal "ERROR 5456:CURRENCY NOT SUPPORTED FOR THIS MERCHANT ACCOUNT", response.message
    assert !response.success?
    assert response.test?
  end
end
