require 'rubygems'
require 'json'

require 'test_helper'

class RemoteStripeTest < Test::Unit::TestCase

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000')

    @options = {
      :description => 'ActiveMerchant Test Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card number is invalid', response.message
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert response.params["uncaptured"]
  end

  def test_unsuccessful_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card number is invalid', response.message
  end

  def test_successful_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    assert captured = @gateway.capture(nil, response.authorization)
    assert_success captured
    assert !captured.params["uncaptured"]
  end

  def test_unsuccessful_capture
    assert captured = @gateway.capture(nil, "active_merchant_fake_charge")
    assert_failure captured
    assert_equal "Invalid charge id: active_merchant_fake_charge", captured.message
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_unsuccessful_void
    assert void = @gateway.void("active_merchant_fake_charge")
    assert_failure void
    assert_equal "Invalid charge id: active_merchant_fake_charge", void.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.refund(@amount - 20, response.authorization)
    assert_success void
  end

  def test_unsuccessful_refund
    assert refund = @gateway.refund(@amount, "active_merchant_fake_charge")
    assert_failure refund
    assert_equal "Invalid charge id: active_merchant_fake_charge", refund.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {:description => "Active Merchant Test Customer"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal @credit_card.last_digits, response.params["active_card"]["last4"]
  end

  def test_invalid_login
    gateway = StripeGateway.new(:login => 'active_merchant_test')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid API Key provided: active_merchant_test", response.message
  end

end
