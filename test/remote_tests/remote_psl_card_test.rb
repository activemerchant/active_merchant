# Author::    MoneySpyder, http://moneyspyder.co.uk

#
# Unit test for PSL Card
#

require File.dirname(__FILE__) + '/../test_helper'

class RemotePslCardTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  # The test results are determined by the amount of the transaction
  ACCEPT_AMOUNT = 1000
  REFERRED_AMOUNT = 6000
  DECLINED_AMOUNT = 11000
  KEEP_CARD_AMOUNT = 15000
  
  CURRENCY = 'GBP'

  def setup
    @gateway = PslCardGateway.new(
      :login => '' # The test account number
    )
    
    # Replace with PSLCard Test Credit information
    @uk_maestro = CreditCard.new(
      :number => '',
      :month => 12,
      :year => 2014,
      :verification_value => '',
      :issue_number => 1,
      :first_name => '',
      :last_name => ''
    )
    @uk_maestro_address = { 
      :address1 => '',
      :address2 => '=',
      :zip => '',
      :country => '',
      :phone => '',
      :name => ''
    }
    
    @solo = CreditCard.new(
      :number => '',
      :month => 06,
      :year => 2008,
      :verification_value => '',
      :issue_number => '',
      :first_name => '',
      :last_name => ''
    )
    @solo_address = {
      :address1 => '',
      :address2 => '',
      :address3 => '',
      :zip => '',
      :country => '',
      :phone => '',
      :name => ''
    }
    
    @visa = CreditCard.new(
      :number => '',
      :month => 12,
      :year => 2009,
      :verification_value => '',
      :first_name => '',
      :last_name => ''
    )
    @visa_address = {
      :address1 => '',
      :address2 => '',
      :address3 => '',
      :address4 => '',
      :zip => '',
      :country => '',
      :phone => '',
      :name => ''
    }
  end
  
  def test_successful_purchase
    options = {
      :billing_address => @solo_address,
      :test => true
    }
    response = @gateway.purchase(Money.new(ACCEPT_AMOUNT, CURRENCY), @solo, options)
    assert response.success?
    assert response.test?
    
    options = {
      :billing_address => @visa_address,
      :test => true
    }
    response = @gateway.purchase(Money.new(ACCEPT_AMOUNT, CURRENCY), @visa, options)
    assert response.success?
    assert response.test?
  end

  def test_unsuccessful_purchase
    options = {
      :billing_address => @uk_maestro_address,
      :test => true
    }
    response = @gateway.purchase(Money.new(REFERRED_AMOUNT, CURRENCY), @uk_maestro, options)
    assert !response.success?
    assert response.test?
    
    response = @gateway.purchase(Money.new(DECLINED_AMOUNT, CURRENCY), @uk_maestro, options)
    assert !response.success?
    assert response.test?
    
    response = @gateway.purchase(Money.new(KEEP_CARD_AMOUNT, CURRENCY), @uk_maestro, options)
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization
    options = {
      :billing_address => @uk_maestro_address,
      :test => true
    }
    response = @gateway.authorize(Money.new(ACCEPT_AMOUNT, CURRENCY), @uk_maestro, options)
    assert response.success?
    assert response.test?
  end
  
  def test_no_login
    options = {
      :billing_address => @uk_maestro_address,
      :test => true
    }
    @gateway = PslCardGateway.new(
      :login => ''
    )
    response = @gateway.authorize(Money.new(ACCEPT_AMOUNT, CURRENCY), @uk_maestro, options)
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    options = {
      :billing_address => @uk_maestro_address,
      :test => true
    }
    amount = Money.new(ACCEPT_AMOUNT, CURRENCY)
    response = @gateway.authorize(amount, @uk_maestro, options)
    assert response.success?
    assert response.test?
    
    auth = response.authorization
    new_response = @gateway.capture(amount, auth)
    assert response.success?
    assert response.test?
  end
end
