require 'test_helper'

class RemoteCyberSourceRestTest < Test::Unit::TestCase
  def setup
    @gateway = CyberSourceRestGateway.new(fixtures(:cybersource_rest))
    @amount = 10221
    @card_without_funds = credit_card('42423482938483873')
    @bank_account = check(account_number: '4100', routing_number: '121042882')
    @declined_bank_account = check(account_number: '550111', routing_number: '121107882')

    @visa_card = credit_card('4111111111111111',
      verification_value: '987',
      month: 12,
      year: 2031)
    @expired_visa_card = credit_card('4111111111111111',
      verification_value: '987',
      month: 12,
      year: Time.now.year - 1)

    @master_card = credit_card('2222420000001113', brand: 'master')
    @discover_card = credit_card('6011111111111117', brand: 'discover')

    @apple_pay = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'AceY+igABPs3jdwNaDg3MAACAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: 569
    )

    @google_pay = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: 569
    )

    @google_pay_master = network_tokenization_credit_card(
      '5555555555554444',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: 569,
      brand: 'master'
    )

    @apple_pay_jcb = network_tokenization_credit_card(
      '3566111111111113',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: 569,
      brand: 'jcb'
    )

    @apple_pay_american_express = network_tokenization_credit_card(
      '378282246310005',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: 569,
      brand: 'american_express'
    )

    @google_pay_discover = network_tokenization_credit_card(
      '6011111111111117',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: 569,
      brand: 'discover'
    )

    @billing_address = {
      name:     'John Doe',
      address1: '1 Market St',
      city:     'san francisco',
      state:    'CA',
      zip:      '94105',
      country:  'US',
      phone:    '4158880000'
    }

    @options = {
      order_id: generate_unique_id,
      currency: 'USD',
      email: 'test@cybs.com',
      billing_address: {
        name:     'John Doe',
        address1: '1 Market St',
        city:     'san francisco',
        state:    'CA',
        zip:      '94105',
        country:  'US',
        phone:    '4158880000'
      }
    }
  end

  def test_handle_credentials_error
    gateway = CyberSourceRestGateway.new({ merchant_id: 'abc123', public_key: 'abc456', private_key: 'def789' })
    response = gateway.authorize(@amount, @visa_card, @options)

    assert_equal('Authentication Failed', response.message)
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @visa_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_successful_authorize_with_billing_address
    @options[:billing_address] = @billing_address
    response = @gateway.authorize(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_failure_authorize_with_declined_credit_card
    response = @gateway.authorize(@amount, @card_without_funds, @options)

    assert_failure response
    assert_match %r{Invalid account}, response.message
    assert_equal 'INVALID_ACCOUNT', response.error_code
  end

  def test_successful_capture
    authorize = @gateway.authorize(@amount, @visa_card, @options)
    response = @gateway.capture(@amount, authorize.authorization, @options)

    assert_success response
    assert_equal 'PENDING', response.message
  end

  def test_successful_capture_with_partial_amount
    authorize = @gateway.authorize(@amount, @visa_card, @options)
    response = @gateway.capture(@amount - 10, authorize.authorization, @options)

    assert_success response
    assert_equal 'PENDING', response.message
  end

  def test_failure_capture_with_higher_amount
    authorize = @gateway.authorize(@amount, @visa_card, @options)
    response = @gateway.capture(@amount + 10, authorize.authorization, @options)

    assert_failure response
    assert_match(/exceeds/, response.params['message'])
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @visa_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_purchase_with_credit_card_ignore_avs
    @options[:ignore_avs] = 'true'
    response = @gateway.purchase(@amount, @visa_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_purchase_with_network_token_ignore_avs
    @options[:ignore_avs] = 'true'
    response = @gateway.purchase(@amount, @apple_pay, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_purchase_with_credit_card_ignore_cvv
    @options[:ignore_cvv] = 'true'
    response = @gateway.purchase(@amount, @visa_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_purchase_with_network_token_ignore_cvv
    @options[:ignore_cvv] = 'true'
    response = @gateway.purchase(@amount, @apple_pay, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response = @gateway.refund(@amount, purchase.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert response.params['_links']['void'].present?
  end

  def test_failure_refund
    purchase = @gateway.purchase(@amount, @card_without_funds, @options)
    response = @gateway.refund(@amount, purchase.authorization, @options)

    assert_failure response
    assert response.test?
    assert_match %r{Declined - One or more fields in the request contains invalid data}, response.params['message']
    assert_equal 'INVALID_DATA', response.params['reason']
  end

  def test_successful_partial_refund
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response = @gateway.refund(@amount / 2, purchase.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert response.params['_links']['void'].present?
  end

  def test_successful_repeat_refund_transaction
    purchase = @gateway.purchase(@amount, @visa_card, @options)
    response1 = @gateway.refund(@amount, purchase.authorization, @options)

    assert_success response1
    assert response1.test?
    assert_equal 'PENDING', response1.message
    assert response1.params['id'].present?
    assert response1.params['_links']['void']

    response2 = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success response2
    assert response2.test?
    assert_equal 'PENDING', response2.message
    assert response2.params['id'].present?
    assert response2.params['_links']['void']

    assert_not_equal response1.params['_links']['void'], response2.params['_links']['void']
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @visa_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.params['id'].present?
    assert_nil response.params['_links']['capture']
  end

  def test_failure_credit
    response = @gateway.credit(@amount, @card_without_funds, @options)

    assert_failure response
    assert response.test?
    assert_match %r{Decline - Invalid account number}, response.message
    assert_equal 'INVALID_ACCOUNT', response.error_code
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @visa_card, @options)
    response = @gateway.void(authorize.authorization, @options)
    assert_success response
    assert response.params['id'].present?
    assert_equal 'REVERSED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_failure_void_using_card_without_funds
    authorize = @gateway.authorize(@amount, @card_without_funds, @options)
    response = @gateway.void(authorize.authorization, @options)
    assert_failure response
    assert_match %r{Declined - The request is missing one or more fields}, response.params['message']
    assert_equal 'INVALID_REQUEST', response.params['status']
  end

  def test_successful_verify
    response = @gateway.verify(@visa_card, @options)
    assert_success response
    assert response.params['id'].present?
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_failure_verify
    response = @gateway.verify(@card_without_funds, @options)
    assert_failure response
    assert_match %r{Decline - Invalid account number}, response.message
    assert_equal 'INVALID_ACCOUNT', response.error_code
  end

  def test_successful_authorize_with_apple_pay
    response = @gateway.authorize(@amount, @apple_pay, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_successful_authorize_with_google_pay
    response = @gateway.authorize(@amount, @apple_pay, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
    refute_empty response.params['_links']['capture']
  end

  def test_successful_purchase_with_apple_pay_jcb
    response = @gateway.purchase(@amount, @apple_pay_jcb, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_purchase_with_apple_pay_american_express
    response = @gateway.purchase(@amount, @apple_pay_american_express, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_purchase_with_google_pay_master
    response = @gateway.purchase(@amount, @google_pay_master, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_authorize_with_google_pay_discover
    response = @gateway.purchase(@amount, @google_pay_discover, @options)

    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_store
    @options[:billing_address] = @billing_address
    response = @gateway.store(@visa_card, @options)
    assert_success response
  end

  def test_successful_store_with_customer_id
    @options[:billing_address] = @billing_address
    response = @gateway.store(@visa_card, @options.merge(customer_id: 'F66C3BB943783F02E053AF598E0A17C9'))
    assert_success response
  end

  def test_successful_purchase_with_stored_card
    @options[:billing_address] = @billing_address
    stored = @gateway.store(@visa_card, @options)
    assert_success stored

    response = @gateway.purchase(@amount, stored.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_purchase_with_stored_card_with_customer_id
    @options[:billing_address] = @billing_address
    stored = @gateway.store(@visa_card, @options.merge(customer_id: 'F66C3BB943783F02E053AF598E0A17C9'))
    response = @gateway.purchase(@amount, stored.authorization, @options)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
  end

  def test_successful_unstore
    @options[:billing_address] = @billing_address
    store_transaction = @gateway.store(@visa_card, @options)
    unstore = @gateway.unstore(store_transaction.authorization)

    assert_success unstore
  end

  def test_failed_store_becuase_customer_id
    @options[:billing_address] = @billing_address
    response = @gateway.store(@visa_card, @options.
      merge(customer_id: 'aso3er'))
    assert_failure response
    assert_equal 'notFound', response.params['errors'][0]['type']
    assert_equal 'Token not found', response.params['errors'][0]['message']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @visa_card, @options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@visa_card.number, transcript)
    assert_scrubbed(@visa_card.verification_value, transcript)
  end

  def test_transcript_scrubbing_bank
    @options[:billing_address] = @billing_address
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @bank_account, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@bank_account.account_number, transcript)
    assert_scrubbed(@bank_account.routing_number, transcript)
  end

  def test_successful_authorize_with_bank_account
    @options[:billing_address] = @billing_address
    response = @gateway.authorize(@amount, @bank_account, @options)
    assert_success response
    assert_equal 'PENDING', response.message
  end

  def test_successful_purchase_with_bank_account
    @options[:billing_address] = @billing_address
    response = @gateway.purchase(@amount, @bank_account, @options)
    assert_success response
    assert_equal 'PENDING', response.message
  end

  def test_failed_authorize_with_bank_account
    @options[:billing_address] = @billing_address
    response = @gateway.authorize(@amount, @declined_bank_account, @options)
    assert_failure response
    assert_equal 'Decline - General decline by the processor.', response.message
  end

  def test_failed_authorize_with_bank_account_missing_country_code
    response = @gateway.authorize(@amount, @bank_account, @options.except(:billing_address))
    assert_failure response
    assert_equal 'Declined - The request is missing one or more fields', response.params['message']
  end

  def stored_credential_options(*args, ntid: nil)
    @options.merge(stored_credential: stored_credential(*args, network_transaction_id: ntid))
  end

  def test_purchase_using_stored_credential_initial_mit
    options = stored_credential_options(:merchant, :internet, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert_success auth
    assert purchase = @gateway.purchase(@amount, @visa_card, options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_recurring_cit
    options = stored_credential_options(:cardholder, :recurring, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert_success auth
    used_store_credentials = stored_credential_options(:cardholder, :recurring, ntid: auth.network_transaction_id)
    used_store_credentials[:reason_code] = '4'
    assert purchase = @gateway.purchase(@amount, @visa_card, used_store_credentials)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_recurring_mit
    options = stored_credential_options(:merchant, :recurring, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert_success auth
    used_store_credentials = stored_credential_options(:merchant, :recurring, ntid: auth.network_transaction_id)
    used_store_credentials[:reason_code] = '4'
    assert purchase = @gateway.purchase(@amount, @visa_card, used_store_credentials)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_cit
    options = stored_credential_options(:cardholder, :installment, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert_success auth
    used_store_credentials = stored_credential_options(:cardholder, :installment, ntid: auth.network_transaction_id)
    used_store_credentials[:reason_code] = '4'
    assert purchase = @gateway.purchase(@amount, @visa_card, used_store_credentials)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_mit
    options = stored_credential_options(:merchant, :installment, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert_success auth
    used_store_credentials = stored_credential_options(:merchant, :installment, ntid: auth.network_transaction_id)
    used_store_credentials[:reason_code] = '4'
    assert purchase = @gateway.purchase(@amount, @visa_card, used_store_credentials)
    assert_success purchase
  end

  def test_failure_stored_credential_invalid_reason_code
    options = stored_credential_options(:cardholder, :internet, :initial)
    assert auth = @gateway.authorize(@amount, @master_card, options)
    assert_equal(auth.params['status'], 'INVALID_REQUEST')
    assert_equal(auth.params['message'], 'Declined - One or more fields in the request contains invalid data')
    assert_equal(auth.params['details'].first['field'], 'processingInformation.authorizationOptions.initiator.merchantInitiatedTransaction.reason')
  end

  def test_auth_and_purchase_with_network_txn_id
    options = stored_credential_options(:merchant, :recurring, :initial)
    options[:reason_code] = '4'
    assert auth = @gateway.authorize(@amount, @visa_card, options)
    assert purchase = @gateway.purchase(@amount, @visa_card, options.merge(network_transaction_id: auth.network_transaction_id))
    assert_success purchase
  end

  def test_successful_purchase_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.purchase(@amount, @visa_card, options)
    assert_success response
  end

  def test_successful_authorization_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.authorize(@amount, @visa_card, options)
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_verify_zero_amount
    @options[:zero_amount_auth] = true
    response = @gateway.verify(@visa_card, @options)
    assert_success response
    assert_match '0.00', response.params['orderInformation']['amountDetails']['authorizedAmount']
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_bank_account_purchase_with_sec_code
    options = @options.merge(sec_code: 'WEB')
    response = @gateway.purchase(@amount, @bank_account, options)
    assert_success response
    assert_equal 'PENDING', response.message
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::CyberSourceRestGateway.application_id = 'A1000000'
    assert response = @gateway.purchase(@amount, @visa_card, @options)
    assert_success response
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_in_australian_dollars
    @options[:currency] = 'AUD'
    response = @gateway.purchase(@amount, @visa_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
    assert_nil response.params['_links']['capture']
    assert_equal 'AUD', response.params['orderInformation']['amountDetails']['currency']
  end
end
