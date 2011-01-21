require 'test_helper'

class RemoteFederatedCanadaTest < Test::Unit::TestCase
  

  def setup
    @gateway = FederatedCanadaGateway.new(fixtures(:federated_canada))
    
    @amount = 100
#    @credit_card = credit_card('6011601160116611') # Discover
    @credit_card = credit_card('4111111111111111') # Visa
#    @credit_card = credit_card('5431111111111111') # MC
#    @credit_card = credit_card( '341111111111111') # AE
		@credit_card.month = '11'
		@credit_card.year = '2011'

    @declined_amount = 99

    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

	def test_gateway_should_exist
		assert @gateway
	end
	
	def test_validity_of_credit_card
		assert @credit_card.valid?
	end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Transaction Declined", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal "Transaction Approved", auth.message

    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal "Error in transaction data or system error", response.message
  end

  def test_invalid_login
    gateway = FederatedCanadaGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Error in transaction data or system error", response.message
  end
end
