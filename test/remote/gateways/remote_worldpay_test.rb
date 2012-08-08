require 'test_helper'

class RemoteWorldpayTest < Test::Unit::TestCase
  

  def setup
    @gateway = WorldpayGateway.new(fixtures(:world_pay_gateway))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4111111111111111', :first_name => nil, :last_name => 'REFUSED')
    
    @options = {:order_id => generate_unique_id}
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'REFUSED', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'bogus')
    assert_failure response
    assert_equal 'Could not find payment for order', response.message
  end

  def test_billing_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(:billing_address => address))
  end

  def test_void
    assert_success(auth = @gateway.authorize(@amount, @credit_card, @options))
    assert_success @gateway.void(auth.authorization)

    assert_failure @gateway.void('bogus')
  end

  # Worldpay has a delay between asking for a transaction to be captured and actually marking it as captured
  # These tests work if you take the auth code, wait some time and then request the refund
  #def test_refund
  #  assert_success(auth = @gateway.authorize(@amount, @credit_card, @options))
  #  assert_success auth
  #  assert_equal 'SUCCESS', auth.message
  #  assert auth.authorization
  #  puts auth.authorization
  #  assert capture = @gateway.capture(@amount, auth.authorization)
  #  assert_success @gateway.refund(@amount, auth.authorization)
  #end
  #
  #def test_refund_existing_transaction
  #  assert_success resp = @gateway.refund(@amount, "7c85e685c35115689ff9c429be9f65e7")
  #  puts resp.inspect
  #end

  def test_currency
    assert_success(result = @gateway.authorize(@amount, @credit_card, @options.merge(:currency => 'USD')))
    assert_equal "USD", result.params['amount_currency_code']
  end

  def test_reference_transaction
    assert_success(original = @gateway.authorize(100, @credit_card, @options))
    assert_success(@gateway.authorize(200, original.authorization, :order_id => generate_unique_id))
  end

  def test_invalid_login
    gateway = WorldpayGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end
end
