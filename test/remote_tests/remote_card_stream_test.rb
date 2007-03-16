# Portions of the Cardstream gateway by Jonah Fox and Thomas Nichols

require File.dirname(__FILE__) + '/../test_helper'

class RemoteCardStreamTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  LOGIN = 'X'
  PASSWORD = 'Y'

  def setup
    @gateway = CardStreamGateway.new(
      :login => LOGIN,
      :password => PASSWORD
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
      :order_id => order_id,
      :description => 'Store purchase'
    }
   
    @maestro_options = {
      :address => { :address1 => 'The Parkway',
                    :address2 => "Larches Approach",
                    :city => "Hull",
                    :state => "North Humberside",
                    :zip => 'HU7 9OP'
                  },
      :order_id => order_id,
      :description => 'Store purchase'
    }
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(Money.new(100, "GBP"), @mastercard, @mastercard_options)
    assert_equal 'APPROVED', response.message
    assert response.success?
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_expired_mastercard
    @mastercard.year = 2005
    assert response = @gateway.purchase(Money.new(100, "GBP"), @mastercard, @mastercard_options)
    assert_equal 'CARD EXPIRED', response.message
    assert !response.success?
    assert response.test?
  end

  def test_successful_maestro_purchase
    assert response = @gateway.purchase(Money.new(100, "GBP"), @maestro, @maestro_options)
    assert_equal 'APPROVED', response.message
    assert response.success?
  end
  
  def test_maestro_missing_start_date_and_issue_date
    @maestro.issue_number = nil
    assert response = @gateway.purchase(Money.new(100, "GBP"), @maestro, @maestro_options)
    assert_equal 'ISSUE NUMBER MISSING', response.message
    assert !response.success?
    assert response.test?
  end
  
  def test_invalid_login
    gateway = CardStreamGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(Money.new(100, 'GBP'), @mastercard, @mastercard_options)
    assert_equal 'Merchant ID or Password Error', response.message
    assert !response.success?
  end
  
  def test_unsupported_merchant_currency
    assert response = @gateway.purchase(Money.new(100, "USD"), @mastercard, @mastercard_options)
    assert_equal "ERROR 5456:CURRENCY NOT SUPPORTED FOR THIS MERCHANT ACCOUNT", response.message
    assert !response.success?
    assert response.test?
  end

private
  def order_id
    "##{rand(100000)}"
  end
end
