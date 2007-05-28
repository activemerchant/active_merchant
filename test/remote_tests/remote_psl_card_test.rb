# Author::    MoneySpyder, http://moneyspyder.co.uk

require File.dirname(__FILE__) + '/../test_helper'

class RemotePslCardTest < Test::Unit::TestCase
  # The test results are determined by the amount of the transaction
  ACCEPT_AMOUNT = 1000
  REFERRED_AMOUNT = 6000
  DECLINED_AMOUNT = 11000
  KEEP_CARD_AMOUNT = 15000

  def setup
    @gateway = PslCardGateway.new(
      :login => '' # The test account number
    )
    
    # Replace with PSLCard Test Credit information
    @uk_maestro = credit_card('',
      :month => 6,
      :year => 2009,
      :verification_value => '',
      :issue_number => '1'
    )
    
    @uk_maestro_address = { 
      :address1 => '',
      :address2 => '',
      :city     => '',
      :state    => '',
      :zip      => ''
    }
    
    @solo = credit_card('',
      :month => 06,
      :year => 2008,
      :verification_value => '',
      :issue_number => '01'
    )
    
    @solo_address = {
      :address1 => '',
      :city     => '',
      :state    => '',
      :zip      => ''
    }
    
    @visa = credit_card('',
      :month => 12,
      :year => 2009,
      :verification_value => ''
    )
    
    @visa_address = {
      :address1 => '',
      :address2 => '',
      :city     => '',
      :state => '',
      :zip      => '' 
    }
  end
  
  def test_successful_visa_purchase
    response = @gateway.purchase(ACCEPT_AMOUNT, @visa,
      :address => @visa_address
    )
    assert response.success?
    assert response.test?
  end
  
  def test_successful_visa_purchase_specifying_currency
    response = @gateway.purchase(ACCEPT_AMOUNT, @visa,
      :address => @visa_address,
      :currency => 'GBP'
    )
    assert response.success?
    assert response.test?
  end
  
  def test_successful_solo_purchase
    response = @gateway.purchase(ACCEPT_AMOUNT, @solo, 
      :address => @solo_address
    )
    assert response.success?
    assert response.test?
  end
  
  def test_referred_purchase
    response = @gateway.purchase(REFERRED_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert !response.success?
    assert response.test?
  end
  
  def test_declined_purchase
    response = @gateway.purchase(DECLINED_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert !response.success?
    assert response.test?
  end
  
  def test_declined_keep_card_purchase
    response = @gateway.purchase(KEEP_CARD_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization
    response = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert response.success?
    assert response.test?
  end
  
  def test_no_login
    @gateway = PslCardGateway.new(
      :login => ''
    )
    response = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert !response.success?
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    authorization = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro,
      :address => @uk_maestro_address
    )
    assert authorization.success?
    assert authorization.test?
    
    capture = @gateway.capture(ACCEPT_AMOUNT, authorization.authorization)
    assert capture.success?
    assert capture.test?
  end
end
