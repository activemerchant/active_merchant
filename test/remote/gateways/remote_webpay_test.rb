# coding: utf-8
require 'test_helper'

class RemoteWebpayTest < Test::Unit::TestCase

  def setup
    @gateway = WebpayGateway.new(fixtures(:webpay))

    @amount = 10000
    @refund_amount = 2000
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000')
    @new_credit_card = credit_card('5105105105105100')

    @options = {
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_appropriate_purchase_amount
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal @amount / 100, response.params["amount"]
  end

  def test_purchase_description
    assert response = @gateway.purchase(@amount, @credit_card, { :description => "TheDescription", :email => "email@example.com" })
    assert_equal "TheDescription", response.params["description"], "Use the description if it's specified."

    assert response = @gateway.purchase(@amount, @credit_card, { :email => "email@example.com" })
    assert_equal "email@example.com", response.params["description"], "Use the email if no description is specified."

    assert response = @gateway.purchase(@amount, @credit_card, { })
    assert_nil response.params["description"], "No description or email specified."
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card number is incorrect', response.message
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
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
    assert_match 'No such charge: active_merchant_fake_charge', void.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.refund(@refund_amount, response.authorization)
    assert_success void
  end

  def test_appropriate_refund_amount
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.refund(@refund_amount, response.authorization)
    assert_success void
    assert_equal @refund_amount / 100, void.params["amount_refunded"]
  end

  def test_unsuccessful_refund
    assert refund = @gateway.refund(@amount, "active_merchant_fake_charge")
    assert_failure refund
    assert_match 'No such charge: active_merchant_fake_charge', refund.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {:description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    assert_equal @credit_card.last_digits, response.params["active_card"]["last4"]
  end

  def test_successful_update
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Update Customer"})
    assert response = @gateway.update(creation.params['id'], @new_credit_card)
    assert_success response
    assert_equal "Active Merchant Update Customer", response.params["description"]
    assert_equal @new_credit_card.last_digits, response.params["active_card"]["last4"]
  end

  def test_successful_unstore
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Unstore Customer"})
    assert response = @gateway.unstore(creation.params['id'])
    assert_success response
    assert_equal true, response.params["deleted"]
  end

  def test_invalid_login
    gateway = WebpayGateway.new(:login => 'active_merchant_test')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid API key provided. Check your API key is correct.", response.message
  end

end
