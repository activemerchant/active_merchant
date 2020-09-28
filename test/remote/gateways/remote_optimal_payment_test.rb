require 'test_helper'

class RemoteOptimalPaymentTest < Test::Unit::TestCase
  def setup
    @gateway = OptimalPaymentGateway.new(fixtures(:optimal_payment))

    @amount = 100
    @declined_amount = 5
    @credit_card = credit_card('4387751111011')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Basic Subscription',
      :email => 'email@example.com',
      :ip => '1.2.3.4'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_unsuccessful_purchase_with_shipping_address
    @options.merge!(:shipping_address => address)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_successful_great_britain
    @options[:billing_address][:country] = "GB"
    @options[:billing_address][:state] = "North West England"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'auth declined', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_invalid_capture
    assert response = @gateway.capture(@amount, 'notgood')
    assert_failure response
    assert_equal 'Invalid authorization id', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '123')
    assert_failure response
    assert_equal 'Authorization transaction not found', response.message
  end

  def test_stored_data_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert stored_purchase = @gateway.stored_purchase(@amount, response.authorization)
    assert_success stored_purchase
  end

  def test_overloaded_stored_data_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert stored_purchase = @gateway.purchase(@amount, response.authorization)
    assert_success stored_purchase
  end

  def test_stored_data_authorize_and_capture
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert auth = @gateway.stored_authorize(@amount, response.authorization)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_overloaded_stored_data_authorize_and_capture
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'no_error', response.message
    assert response.authorization

    assert auth = @gateway.authorize(@amount, response.authorization)
    assert_success auth
    assert_equal 'no_error', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_invalid_login
    gateway = OptimalPaymentGateway.new(
                :account_number => '1',
                :store_id => 'bad',
                :password => 'bad'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'invalid credentials', response.message
  end
end
