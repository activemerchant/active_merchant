require 'test_helper'

class RemoteStripeTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_[a-zA-Z\d]+/

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))
    @currency = fixtures(:stripe)["currency"]

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000000000000002')
    @new_credit_card = credit_card('5105105105105100')

    @options = {
      :currency => @currency,
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
    @apple_pay_payment_token = apple_pay_payment_token
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_purchase_with_apple_pay_payment_token
    assert response = @gateway.purchase(@amount, @apple_pay_payment_token, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_purchase_with_recurring_flag
    custom_options = @options.merge(:eci => 'recurring')
    assert response = @gateway.purchase(@amount, @credit_card, custom_options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{Your card was declined}, response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]
    assert_equal "ActiveMerchant Test Purchase", authorization.params["description"]
    assert_equal "wow@example.com", authorization.params["metadata"]["email"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_authorization_and_capture_with_apple_pay_payment_token
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_success authorization
    assert !authorization.params["captured"]
    assert_equal "ActiveMerchant Test Purchase", authorization.params["description"]
    assert_equal "wow@example.com", authorization.params["metadata"]["email"]

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

  def test_authorization_and_void_with_apple_pay_payment_token
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
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

  def test_successful_void_with_apple_pay_payment_token
    assert response = @gateway.purchase(@amount, @apple_pay_payment_token, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_unsuccessful_void
    assert void = @gateway.void("active_merchant_fake_charge")
    assert_failure void
    assert_match %r{active_merchant_fake_charge}, void.message
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
    assert_match %r{active_merchant_fake_charge}, refund.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Transaction approved", response.message
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_equal "charge", response.params["object"]
    assert_success response.responses.last, "The void should succeed"
    assert response.responses.last.params["refunded"]
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Your card was declined}, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, {:currency => @currency, :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["cards"]["data"].first
    assert_equal response.params["default_card"], first_card["id"]
    assert_equal @credit_card.last_digits, first_card["last4"]
  end

  def test_successful_store_with_existing_customer
    assert response = @gateway.store(@credit_card, {:currency => @currency, :description => "Active Merchant Test Customer"})
    assert_success response

    assert response = @gateway.store(@new_credit_card, {:customer => response.params['id'], :currency => @currency, :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal 2, response.responses.size

    card_response = response.responses[0]
    assert_equal "card", card_response.params["object"]
    assert_equal @new_credit_card.last_digits, card_response.params["last4"]

    customer_response = response.responses[1]
    assert_equal "customer", customer_response.params["object"]
    assert_equal "Active Merchant Test Customer", customer_response.params["description"]
    assert_equal "email@example.com", customer_response.params["email"]
    assert_equal 2, customer_response.params["cards"]["count"]
  end

  def test_successful_unstore
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Unstore Customer"})
    customer_id = creation.params['id']
    card_id = creation.params['cards']['data'].first['id']

    # Unstore the card
    assert response = @gateway.unstore(customer_id, card_id: card_id)
    assert_success response
    assert_equal card_id, response.params['id']
    assert_equal true, response.params['deleted']

    # Unstore the customer
    assert response = @gateway.unstore(customer_id)
    assert_success response
    assert_equal customer_id, response.params['id']
    assert_equal true, response.params['deleted']
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
    assert_equal 0, refund.params["fee"]
  end

  def test_refund_partial_application_fee
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:application_fee => 12))
    assert response.params['fee_details'], 'This test will only work if your gateway login is a Stripe Connect access_token.'
    assert refund = @gateway.refund(@amount - 20, response.authorization, { :refund_fee_amount => 10 })
    assert_success refund
  end

  def test_creditcard_purchase_with_customer
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:customer => '1234'))
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_expanding_objects
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(:expand => 'balance_transaction'))
    assert_success response
    assert response.params['balance_transaction'].is_a?(Hash)
    assert_equal 'balance_transaction', response.params['balance_transaction']['object']
  end

  def test_successful_update
    creation    = @gateway.store(@credit_card, {:description => "Active Merchant Update Credit Card"})
    customer_id = creation.params['id']
    card_id     = creation.params['cards']['data'].first['id']

    assert response = @gateway.update(customer_id, card_id, { :name => "John Doe", :address_line1 => "123 Main Street", :address_city => "Pleasantville", :address_state => "NY", :address_zip => "12345", :exp_year => Time.now.year + 2, :exp_month => 6 })
    assert_success response
    assert_equal "John Doe",        response.params["name"]
    assert_equal "123 Main Street", response.params["address_line1"]
    assert_equal "Pleasantville",   response.params["address_city"]
    assert_equal "NY",              response.params["address_state"]
    assert_equal "12345",           response.params["address_zip"]
    assert_equal Time.now.year + 2, response.params["exp_year"]
    assert_equal 6,                 response.params["exp_month"]
  end

  def test_incorrect_number_for_purchase
    card = credit_card('4242424242424241')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_invalid_number_for_purchase
    card = credit_card('-1')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_invalid_expiry_month_for_purchase
    card = credit_card('4242424242424242', month: 16)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_invalid_expiry_year_for_purchase
    card = credit_card('4242424242424242', year: 'xx')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_expired_card_for_purchase
    card = credit_card('4000000000000069')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_invalid_cvc_for_purchase
    card = credit_card('4242424242424242', verification_value: -1)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_incorrect_cvc_for_purchase
    card = credit_card('4000000000000127')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_cvc], response.error_code
  end

  def test_processing_error
    card = credit_card('4000000000000119')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_unsuccessful_apple_pay_token_exchange
    assert_raises(ActiveMerchant::Billing::StripeGateway::ApplePayTokenExchangeError) do
      @gateway.purchase(@amount, ApplePayPaymentToken.new('garbage'), @options)
    end
  end

  private

  def apple_pay_payment_token(options = {})
    defaults = {
      payment_data: {
        'version' => 'EC_v1',
        'data' => 'yXTNZRG5DHVQ9hSmmWylwwmYqQ18VMj1pZfPQTGYVMJAWuwMAR84kw6ZJ6jzinNQc/ZHhUQemkaV5IGiynSxVnjz1F6riv4hzLBb9S57of0CB06UtdDMnkzzXTyRMc1Df+hHz5ZPLcMw2X1KEwa0r2D7y6HcyU93g1iQgKrmzBhn2cOnmkFi/LvJCuf5hb23hRnLwcHIvi446EUxuAKenV23f4VnFC9zm+Mvm3VoFuFb8nbdPsegzSJwAWdLMa1/RksPhe7z7DNuFL4cIJ3Wkv3XF9PTcB/5oGSKWc43ZeITLDWE/ZD8ARWdoXuuvcx3XlSbxMpcFimOnRQ820E40mXId97edJ6yTxnJIZmFRbFXZp0ZP4XK5vF0H42poiImsvFKYT/0Dl1OkwTcOgQ7TFkkflACmv/S3ev7T+Q=',
        'signature' => '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',
        'header' => {
          'transactionId' => 'c3f38ca4bf15b07bd2350e864b6a9830055e9087ca34fe97d6dc7c65a01c52e1',
          'ephemeralPublicKey' => 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEHp5oiwiD3vNZT+twuCRkcTlkLjM8ypUuNDhw96V8g6OS+k1mcI05KFMeNt8/1uuXoQxQNikWt2a5SAPJoqaoqg==',
          'publicKeyHash' => 'Ci9X1dBsgmA00sBIGFy1POBdlIGWIcCBtBiheH3m32Q='
        }
      },
      payment_instrument_name: "Visa 2424",
      payment_network: "Visa",
      transaction_identifier: "uniqueidentifier123"
    }.update(options)

    ActiveMerchant::Billing::ApplePayPaymentToken.new(defaults[:payment_data],
      payment_instrument_name: defaults[:payment_instrument_name],
      payment_network: defaults[:payment_network],
      transaction_identifier: defaults[:transaction_identifier]
    )
  end
end
