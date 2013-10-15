require 'test_helper'

class RemoteStripeTest < Test::Unit::TestCase

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000')
    @new_credit_card = credit_card('5105105105105100')

    @options = {
      :currency => 'CAD',
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com',
      :currency => 'CAD'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_purchase_description
    assert response = @gateway.purchase(@amount, @credit_card, { :currency => 'CAD', :description => "TheDescription", :email => "email@example.com" })
    assert_equal "TheDescription", response.params["description"], "Use the description if it's specified."

    assert response = @gateway.purchase(@amount, @credit_card, { :currency => 'CAD', :email => "email@example.com" })
    assert_equal "email@example.com", response.params["description"], "Use the email if no description is specified."

    assert response = @gateway.purchase(@amount, @credit_card, { :currency => 'CAD' })
    assert_nil response.params["description"], "No description or email specified."
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /card number.* invalid/, response.message
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
    assert_match /active_merchant_fake_charge/, void.message
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
    assert_match /active_merchant_fake_charge/, refund.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {:currency => 'CAD', :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["cards"]["data"].first
    assert_equal response.params["default_card"], first_card["id"]
    assert_equal @credit_card.last_digits, first_card["last4"]
  end

  def test_successful_update
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Update Customer"})
    assert response = @gateway.update(creation.params['id'], @new_credit_card)
    assert_success response
    assert_equal "Active Merchant Update Customer", response.params["description"]
    first_card = response.params["cards"]["data"].first
    assert_equal response.params["default_card"], first_card["id"]
    assert_equal @new_credit_card.last_digits, first_card["last4"]
  end

  def test_successful_unstore
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Unstore Customer"})
    assert response = @gateway.unstore(creation.params['id'])
    assert_success response
    assert_equal true, response.params["deleted"]
  end

  def test_successful_recurring
    assert response = @gateway.store(@credit_card, {:description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert recharge_options = @options.merge(:customer => response.params["id"])
    assert response = @gateway.purchase(@amount, nil, recharge_options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_invalid_login
    gateway = StripeGateway.new(:login => 'active_merchant_test')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Invalid API Key provided", response.message
  end

  def test_application_fee_for_stripe_connect
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12 ))
    assert response.params['fee_details'], 'This test will only work if your gateway login is a Stripe Connect access_token.'
    assert response.params['fee_details'].any? do |fee|
      (fee['type'] == 'application_fee') && (fee['amount'] == 12)
    end
  end

  def test_card_present_purchase
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_card_present_authorize_and_capture
    @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_successful_refund_with_application_fee
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert response.params['fee_details'], 'This test will only work if your gateway login is a Stripe Connect access_token.'
    assert refund = @gateway.refund(@amount, response.authorization, :refund_application_fee => true)
    assert_success refund
    assert_equal 12, refund.params["fee_details"].first["amount_refunded"]
  end

  def test_refund_partial_application_fee
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert response.params['fee_details'], 'This test will only work if your gateway login is a Stripe Connect access_token.'
    assert refund = @gateway.refund(@amount - 20, response.authorization, { :refund_fee_amount => 10 })
    assert_success refund
  end
end
