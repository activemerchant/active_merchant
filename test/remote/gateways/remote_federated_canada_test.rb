require 'test_helper'

class RemoteFederatedCanadaTest < Test::Unit::TestCase

  def setup
    @gateway = FederatedCanadaGateway.new(fixtures(:federated_canada))

    @amount = 100
    @declined_amount = 99

    @credit_card = credit_card('4111111111111111') # Visa

    @options = { 
      :order_id => ActiveMerchant::Utils.generate_unique_id,
      :billing_address => address,
      :description => 'Active Merchant Remote Test Purchase'
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

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal "Error in transaction data or system error", response.message
  end

  def test_purchase_and_refund
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Transaction Approved", auth.message
    assert auth.authorization
    assert capture = @gateway.refund(@amount, auth.authorization)
    assert_equal "Transaction Approved", capture.message
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Transaction Approved", auth.message
    assert auth.authorization
    assert capture = @gateway.void(auth.authorization)
    assert_equal "Transaction Approved", capture.message
    assert_success capture
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Transaction Approved", auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_equal "Transaction Approved", capture.message
    assert_success capture
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
