# Author::    MoneySpyder, http://moneyspyder.co.uk

require File.dirname(__FILE__) + '/../test_helper'

class RemotePslCardTest < Test::Unit::TestCase
  # The test results are determined by the amount of the transaction
  ACCEPT_AMOUNT = 1000
  REFERRED_AMOUNT = 6000
  DECLINED_AMOUNT = 11000
  KEEP_CARD_AMOUNT = 15000

  def setup
    @gateway = PslCardGateway.new(fixtures(:psl_card))
    
    @uk_maestro = CreditCard.new(fixtures(:psl_maestro))
    @uk_maestro_address = fixtures(:psl_maestro_address)
    
    @solo = CreditCard.new(fixtures(:psl_solo))
    @solo_address = fixtures(:psl_solo_address)
    
    @visa = CreditCard.new(fixtures(:psl_visa))
    @visa_address = fixtures(:psl_visa_address)
  end
  
  def test_successful_visa_purchase
    response = @gateway.purchase(ACCEPT_AMOUNT, @visa,
      :address => @visa_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_successful_visa_purchase_specifying_currency
    response = @gateway.purchase(ACCEPT_AMOUNT, @visa,
      :address => @visa_address,
      :currency => 'GBP'
    )
    assert_success response
    assert response.test?
  end
  
  def test_successful_solo_purchase
    response = @gateway.purchase(ACCEPT_AMOUNT, @solo, 
      :address => @solo_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_referred_purchase
    response = @gateway.purchase(REFERRED_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_declined_purchase
    response = @gateway.purchase(DECLINED_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_declined_keep_card_purchase
    response = @gateway.purchase(KEEP_CARD_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_successful_authorization
    response = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_no_login
    @gateway = PslCardGateway.new(
      :login => ''
    )
    response = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro, 
      :address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    authorization = @gateway.authorize(ACCEPT_AMOUNT, @uk_maestro,
      :address => @uk_maestro_address
    )
    assert_success authorization
    assert authorization.test?
    
    capture = @gateway.capture(ACCEPT_AMOUNT, authorization.authorization)
    
    assert_success capture
    assert capture.test?
  end
end
