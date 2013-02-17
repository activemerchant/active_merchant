require 'test_helper'

class RemoteEvoCaTest < Test::Unit::TestCase
  def setup
    @gateway = EvoCaGateway.new(fixtures(:evo_ca))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :invoice => 'AB-1234',
      :email => 'evo@example.com',
      :ip => '127.0.0.1'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal EvoCaGateway::MESSAGES[100], response.message
    assert_equal 'SUCCESS', response.params['responsetext']
  end

  def test_unsuccessful_purchase
    # To cause a declined message, pass an amount less than $1.00
    assert response = @gateway.purchase(5, @credit_card, @options)
    assert_failure response
    assert_equal EvoCaGateway::MESSAGES[200], response.message
    assert_equal 'DECLINE', response.params['responsetext']
  end

  def test_purchase_error
    # To trigger a fatal error message, pass an invalid card number.
    assert response = @gateway.purchase(@amount, credit_card('1'), @options)
    assert_failure response
    assert_equal EvoCaGateway::MESSAGES[300], response.message
  end

  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, check, @options)
    assert_success response
    assert_equal EvoCaGateway::MESSAGES[100], response.message
    assert_not_empty response.authorization
    assert_equal 'SUCCESS', response.params['responsetext']
  end

  def test_unsuccessful_check_purchase
    # To cause a declined message, pass an amount less than $1.00
    assert response = @gateway.purchase(1, check, @options)
    assert_failure response
    assert_equal 'FAILED', response.params['responsetext']
  end

  def test_purchase_and_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert refund = @gateway.refund(50, response.authorization)
    assert_success refund
    assert_equal EvoCaGateway::MESSAGES[100], refund.message
  end

  def test_purchase_and_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert void = @gateway.void(response.authorization)
    assert_success void
    assert_equal EvoCaGateway::MESSAGES[100], void.message
  end

  def test_purchase_and_update
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response = @gateway.update(response.authorization, :shipping_carrier => 'fedex', :tracking_number => '12345')
    assert_success response
    assert_equal EvoCaGateway::MESSAGES[100], response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal EvoCaGateway::MESSAGES[100], auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal EvoCaGateway::MESSAGES[300], response.message
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal EvoCaGateway::MESSAGES[100], response.message
    assert_equal 'SUCCESS', response.params['responsetext']
  end

  def test_avs_match
    # To simulate an AVS Match, pass 888 in the address1 field, 77777 for zip.
    opts = @options.merge(:billing_address => address({:address1 => '888', :zip => '77777'}))
    assert response = @gateway.purchase(@amount, @credit_card, opts)
    assert_success response
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end

  def test_cvv_match
    # To simulate a CVV Match, pass 999 in the cvv field.
    assert response = @gateway.purchase(@amount, credit_card('4111111111111111', :verification_value => 999), @options)
    assert_success response
    assert_equal 'M', response.cvv_result['code']
  end
end
