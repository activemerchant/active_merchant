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

    @emv_credit_cards = {
      uk: ActiveMerchant::Billing::CreditCard.new(icc_data: '500B56495341204352454449545F201A56495341204143515549524552205445535420434152442030315F24031512315F280208405F2A0208265F300202015F34010182025C008407A0000000031010950502000080009A031408259B02E8009C01009F02060000000734499F03060000000000009F0607A00000000310109F0902008C9F100706010A03A080009F120F4352454449544F20444520564953419F1A0208269F1C0831373030303437309F1E0831373030303437309F2608EB2EC0F472BEA0A49F2701809F3303E0B8C89F34031E03009F3501229F360200C39F37040A27296F9F4104000001319F4502DAC5DFAE5711476173FFFFFF0119D15122011758989389DFAE5A08476173FFFFFF011957114761739001010119D151220117589893895A084761739001010119'),
      us: ActiveMerchant::Billing::CreditCard.new(icc_data: '500B564953412043524544495457114761739001010119D151220117589893895A0847617390010101195F201A56495341204143515549524552205445535420434152442030315F24031512315F280208405F2A0208405F300202015F34010182025C008407A0000000031010950502000080009A031504209B02E8009C01009F02060000000006959F03060000000000009F0607A00000000310109F0902008C9F100706010A03A080009F120F4352454449544F20444520564953419F1A0208409F1C0831303030333237389F1E0831303030333237389F2608C498749AE7D3AC8E9F2701809F3303E0B8C89F34031E03009F3501229F360202E79F370443597EE89F4104000000099F4502DAC5DFAE5711476173FFFFFF0119D15122011758989389DFAE5A08476173FFFFFF0119')
    }

    @options = {
      :currency => @currency,
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
    @apple_pay_payment_token = apple_pay_payment_token
  end

  def test_dump_transcript
    skip("Transcript scrubbing for this gateway has been tested.")
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
  end

  # this actually shouldn't be legal
  def test_successful_purchase_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures(:stripe_emv_uk))
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:uk], @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  # this shouldn't work technically
  def test_successful_purchase_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert response = @gateway.purchase(@amount, @emv_credit_cards[:us], @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
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

  def test_authorization_and_capture_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures(:stripe_emv_uk))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    assert !authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
  end

  def test_authorization_and_capture_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures(:stripe_emv_us))
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    assert !authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert capture.emv_authorization, "Capture should contain emv_authorization containing the EMV TC"
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

  def test_authorization_and_void_with_emv_credit_card_in_us
    @gateway = StripeGateway.new(fixtures[:stripe_emv_us])
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:us], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
    assert !authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_authorization_and_void_with_emv_credit_card_in_uk
    @gateway = StripeGateway.new(fixtures[:stripe_emv_uk])
    assert authorization = @gateway.authorize(@amount, @emv_credit_cards[:uk], @options)
    assert_success authorization
    assert authorization.emv_authorization, "Authorization should contain emv_authorization containing the EMV ARPC"
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

  def test_successful_store_with_apple_pay_payment_token
    assert response = @gateway.store(@apple_pay_payment_token, {:currency => @currency, :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["cards"]["data"].first
    assert_equal response.params["default_card"], first_card["id"]
    assert_equal "4242", first_card["dynamic_last4"] # when stripe is in test mode, token exchanged will return a test card with dynamic_last4 4242
    assert_equal "0000", first_card["last4"] # last4 is 0000 when using an apple pay token
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

  def test_successful_store_with_existing_customer_and_apple_pay_payment_token
    assert response = @gateway.store(@credit_card, {:currency => @currency, :description => "Active Merchant Test Customer"})
    assert_success response

    assert response = @gateway.store(@apple_pay_payment_token, {:customer => response.params['id'], :currency => @currency, :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal 2, response.responses.size

    card_response = response.responses[0]
    assert_equal "card", card_response.params["object"]
    assert_equal "4242", card_response.params["dynamic_last4"] # when stripe is in test mode, token exchanged will return a test card with dynamic_last4 4242
    assert_equal "0000", card_response.params["last4"] # last4 is 0000 when using an apple pay token

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

  def test_successful_recurring_with_apple_pay_payment_token
    assert response = @gateway.store(@apple_pay_payment_token, {:description => "Active Merchant Test Customer", :email => "email@example.com"})
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

  def test_purchase_with_unsuccessful_apple_pay_token_exchange
    assert response = @gateway.purchase(@amount, ApplePayPaymentToken.new('garbage'), @options)
    assert_failure response
  end

  def test_successful_purchase_with_apple_pay_raw_cryptogram
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_auth_with_apple_pay_raw_cryptogram
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil
    )
    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end
end
