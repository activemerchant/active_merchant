require 'test_helper'

class RemoteStripeTest < Test::Unit::TestCase
  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000000000000002')
    @new_credit_card = credit_card('5105105105105100')
    @debit_card = credit_card('4000056655665556')

    @check = check({
      bank_name: "STRIPE TEST BANK",
      account_number: "000123456789",
      routing_number: "110000000",
    })
    @verified_bank_account = fixtures(:stripe_verified_bank_account)

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
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
    assert_equal response.authorization, response.params["id"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
  end

  def test_successful_purchase_with_blank_referer
    options = @options.merge({referrer: ""})
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert_equal response.authorization, response.params["id"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
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
    assert_match /ch_[a-zA-Z\d]+/, response.authorization
  end

  def test_successful_echeck_purchase_with_verified_account
    customer_id = @verified_bank_account[:customer_id]
    bank_account_id = @verified_bank_account[:bank_account_id]

    payment = [customer_id, bank_account_id].join('|')

    response = @gateway.purchase(@amount, payment, @options)
    assert_success response
    assert response.test?
    assert_equal "Transaction approved", response.message
  end

  def test_unsuccessful_direct_bank_account_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_failure response
    assert_equal "Direct bank account transactions are not supported. Bank accounts must be stored and verified before use.", response.message
  end

  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    refute authorization.params["captured"]
    assert_equal "ActiveMerchant Test Purchase", authorization.params["description"]
    assert_equal "wow@example.com", authorization.params["metadata"]["email"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    refute authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_successful_void
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization)
    assert void.test?
    assert_success void
  end

  def test_successful_void_with_metadata
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    assert void = @gateway.void(response.authorization, metadata: { test_metadata: 123 })
    assert void.test?
    assert_success void
    assert_equal "123", void.params["metadata"]["test_metadata"]
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
    assert refund = @gateway.refund(@amount - 20, response.authorization)
    assert refund.test?
    refund_id = refund.params["id"]
    assert_equal refund.authorization, refund_id
    assert_success refund
  end

  def test_successful_refund_on_verified_bank_account
    customer_id = @verified_bank_account[:customer_id]
    bank_account_id = @verified_bank_account[:bank_account_id]
    payment = [customer_id, bank_account_id].join('|')

    purchase = @gateway.purchase(@amount, payment, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert refund.test?
    refund_id = refund.params["id"]
    assert_equal refund.authorization, refund_id
  end

  def test_refund_with_reverse_transfer
    destination = fixtures(:stripe_destination)[:stripe_user_id]
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(destination: destination))
    assert_success response

    assert refund = @gateway.refund(@amount - 20, response.authorization, reverse_transfer: true)
    assert_success refund
    assert_equal "Transaction approved", refund.message
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
    assert_equal "refund", response.responses.last.params["object"]
  end

  def test_successful_verify_cad
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "cad"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "cad", response.params["currency"]
  end

  def test_successful_verify_gbp
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "gbp"))
    assert_success response
    assert_equal 60, response.params["amount"]
    assert_equal "gbp", response.params["currency"]
  end

  def test_successful_verify_eur
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "eur"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "eur", response.params["currency"]
  end

  def test_successful_verify_dkk
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "dkk"))
    assert_success response
    assert_equal 500, response.params["amount"]
    assert_equal "dkk", response.params["currency"]
  end

  def test_successful_verify_nok
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "nok"))
    assert_success response
    assert_equal 600, response.params["amount"]
    assert_equal "nok", response.params["currency"]
  end

  def test_successful_verify_sek
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "sek"))
    assert_success response
    assert_equal 600, response.params["amount"]
    assert_equal "sek", response.params["currency"]
  end

  def test_successful_verify_chf
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "chf"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "chf", response.params["currency"]
  end

  def test_successful_verify_aud
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "aud"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "aud", response.params["currency"]
  end

  def test_successful_verify_jpy
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "jpy"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "jpy", response.params["currency"]
  end

  def test_successful_verify_mxn
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "mxn"))
    assert_success response
    assert_equal 2000, response.params["amount"]
    assert_equal "mxn", response.params["currency"]
  end

  def test_successful_verify_sgd
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "sgd"))
    assert_success response
    assert_equal 100, response.params["amount"]
    assert_equal "sgd", response.params["currency"]
  end

  def test_successful_verify_hkd
    assert response = @gateway.verify(@credit_card, @options.merge(currency: "hkd"))
    assert_success response
    assert_equal 800, response.params["amount"]
    assert_equal "hkd", response.params["currency"]
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Your card was declined}, response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, description: "TheDescription", email: "email@example.com")
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "TheDescription", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["sources"]["data"].first
    assert_equal response.params["default_source"], first_card["id"]
    assert_equal @credit_card.last_digits, first_card["last4"]
  end

  def test_successful_store_with_validate_false
    assert response = @gateway.store(@credit_card, validate: false)
    assert_success response
    assert_equal "customer", response.params["object"]
  end

  def test_successful_store_with_existing_customer
    assert response = @gateway.store(@credit_card)
    assert_success response

    assert response = @gateway.store(@new_credit_card, customer: response.params['id'], email: "email@example.com", description: "TheDesc")
    assert_success response
    assert_equal 2, response.responses.size

    card_response = response.responses[0]
    assert_equal "card", card_response.params["object"]
    assert_equal @new_credit_card.last_digits, card_response.params["last4"]

    customer_response = response.responses[1]
    assert_equal "customer", customer_response.params["object"]
    assert_equal "TheDesc", customer_response.params["description"]
    assert_equal "email@example.com", customer_response.params["email"]
    assert_equal 2, customer_response.params["sources"]["total_count"]
  end

  def test_successful_store_with_existing_account
    account = fixtures(:stripe_destination)[:stripe_user_id]

    assert response = @gateway.store(@debit_card, account: account)
    assert_success response
    assert_equal "card", response.params["object"]
  end

  def test_successful_purchase_using_stored_card
    assert store = @gateway.store(@credit_card)
    assert_success store

    assert response = @gateway.purchase(@amount, store.authorization)
    assert_success response
    assert_equal "Transaction approved", response.message

    assert response.params["paid"]
    assert_equal "4242", response.params["source"]["last4"]
  end

  def test_successful_purchase_using_stored_card_on_existing_customer
    assert first_store_response = @gateway.store(@credit_card)
    assert_success first_store_response

    assert second_store_response = @gateway.store(@new_credit_card, customer: first_store_response.params['id'])
    assert_success second_store_response

    assert response = @gateway.purchase(@amount, second_store_response.authorization)
    assert_success response
    assert_equal "5100", response.params["source"]["last4"]
  end

  def test_successful_purchase_using_stored_card_and_deprecated_api
    assert store = @gateway.store(@credit_card)
    assert_success store

    recharge_options = @options.merge(:customer => store.params["id"])
    assert_deprecation_warning do
      response = @gateway.purchase(@amount, nil, recharge_options)
      assert_success response
      assert_equal "4242", response.params["source"]["last4"]
    end
  end

  def test_successful_unstore
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Unstore Customer"})
    card_id = creation.params['sources']['data'].first['id']

    assert response = @gateway.unstore(creation.authorization)
    assert_success response
    assert_equal card_id, response.params['id']
    assert_equal true, response.params['deleted']
    assert_equal "Transaction approved", response.message
  end

  def test_successful_unstore_using_deprecated_api
    creation = @gateway.store(@credit_card, {:description => "Active Merchant Unstore Customer"})
    card_id = creation.params['sources']['data'].first['id']
    customer_id = creation.params["id"]

    assert_deprecation_warning do
      response = @gateway.unstore(customer_id, card_id)
      assert_success response
      assert_equal true, response.params['deleted']
    end
  end

  def test_successful_store_of_bank_account
    response = @gateway.store(@check, @options)
    assert_success response
    customer_id, bank_account_id = response.authorization.split('|')
    assert_match /^cus_/, customer_id
    assert_match /^ba_/, bank_account_id
  end

  def test_unsuccessful_purchase_from_stored_but_unverified_bank_account
    store = @gateway.store(@check)
    assert_success store

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_failure purchase
    assert_match "The customer's bank account must be verified", purchase.message
  end

  def test_successful_purchase_from_stored_and_verified_bank_account
    store = @gateway.store(@check)
    assert_success store

    # verify the account using special test amounts from Stripe
    # https://stripe.com/docs/guides/ach#manually-collecting-and-verifying-bank-accounts
    customer_id, bank_account_id = store.authorization.split('|')
    verify_url = "customers/#{customer_id}/sources/#{bank_account_id}/verify"
    verify_response = @gateway.send(:api_request, :post, verify_url, { amounts: [32, 45] })
    assert_match "verified", verify_response["status"]

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
  end

  def test_invalid_login
    gateway = StripeGateway.new(:login => 'active_merchant_test')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Invalid API Key provided", response.message
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
    refute authorization.params["captured"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
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
    card_id     = creation.params['sources']['data'].first['id']

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

  def test_statement_description
    assert response = @gateway.purchase(@amount, @credit_card, statement_description: "Eggcellent Description")
    assert_success response
    assert_equal "Eggcellent Description", response.params["statement_descriptor"]
  end

  def test_stripe_account_header
    account = fixtures(:stripe_destination)[:stripe_user_id]
    assert response = @gateway.purchase(@amount, @credit_card, stripe_account: account)
    assert_success response
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = StripeGateway.new(login: 'an_unknown_api_key')
    assert !gateway.verify_credentials
  end

end
