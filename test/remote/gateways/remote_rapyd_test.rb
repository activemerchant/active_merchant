require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = RapydGateway.new(fixtures(:rapyd))
    @gateway_payment_redirect = RapydGateway.new(fixtures(:rapyd).merge(url_override: 'payment_redirect'))
    @amount = 100
    @credit_card = credit_card('4111111111111111', first_name: 'Ryan', last_name: 'Reynolds', month: '12', year: '2035', verification_value: '345')
    @declined_card = credit_card('4111111111111105')
    @check = check
    @options = {
      pm_type: 'GI_visa_card',
      currency: 'USD',
      complete_payment_url: 'www.google.com',
      error_payment_url: 'www.google.com',
      description: 'Describe this transaction',
      statement_descriptor: 'Statement Descriptor',
      email: 'test@example.com',
      billing_address: address(name: 'Jim Reynolds'),
      order_id: '987654321'
    }
    @stored_credential_options = {
      pm_type: 'gb_visa_card',
      currency: 'GBP',
      complete_payment_url: 'https://www.rapyd.net/platform/collect/online/',
      error_payment_url: 'https://www.rapyd.net/platform/collect/online/',
      description: 'Describe this transaction',
      statement_descriptor: 'Statement Descriptor',
      email: 'test@example.com',
      billing_address: address(name: 'Jim Reynolds'),
      order_id: '987654321'
    }
    @ach_options = {
      pm_type: 'us_ach_bank',
      currency: 'USD',
      proof_of_authorization: false,
      payment_purpose: 'Testing Purpose',
      email: 'test@example.com',
      billing_address: address(name: 'Jim Reynolds')
    }
    @metadata = {
      array_of_objects: [
        { name: 'John Doe' },
        { type: 'customer' }
      ],
      array_of_strings: %w[
        color
        size
      ],
      number: 1234567890,
      object: {
        string: 'person'
      },
      string: 'preferred',
      Boolean: true
    }
    @three_d_secure = {
      version: '2.1.0',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: '00000000000000000501',
      eci: '02'
    }

    @address_object = address(line_1: '123 State Street', line_2: 'Apt. 34', zip: '12345', name: 'john doe', phone_number: '12125559999')
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_without_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: { phone_number: '12125559999' }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_for_idempotent_requests
    response = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: '1234567890'))
    assert_success response
    assert_equal 'SUCCESS', response.message
    original_operation_id = response.params['status']['operation_id']
    original_data_id = response.params['data']['id']
    idempotent_request = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: '1234567890'))
    assert_success idempotent_request
    assert_equal 'SUCCESS', idempotent_request.message
    assert_equal original_operation_id, idempotent_request.params['status']['operation_id']
    assert_equal original_data_id, idempotent_request.params['data']['id']
  end

  def test_successful_purchase_for_non_idempotent_requests
    # is not a idemptent request due the amount is different
    response = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: '1234567890'))
    assert_success response
    assert_equal 'SUCCESS', response.message
    original_operation_id = response.params['status']['operation_id']
    idempotent_request = @gateway.purchase(25, @credit_card, @options.merge(idempotency_key: '1234567890'))
    assert_success idempotent_request
    assert_equal 'SUCCESS', idempotent_request.message
    assert_not_equal original_operation_id, idempotent_request.params['status']['operation_id']
  end

  def test_successful_authorize_with_mastercard
    @options[:pm_type] = 'us_debit_mastercard_card'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_mastercard
    @options[:pm_type] = 'us_debit_mastercard_card'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_success_purchase_without_address_object_customer
    @options[:pm_type] = 'us_debit_discover_card'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_subsequent_purchase_with_stored_credential
    # Rapyd requires a random int between 10 and 15 digits for NTID
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(stored_credential: { network_transaction_id: rand.to_s[2..11], reason_type: 'recurring' }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_transaction_id_and_initiation_type_fields
    # Rapyd requires a random int between 10 and 15 digits for NTID
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(network_transaction_id: rand.to_s[2..11], initiation_type: 'customer_present'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_transaction_id_and_initiation_type_fields_along_with_stored_credentials
    # Rapyd requires a random int between 10 and 15 digits for NTID
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(stored_credential: { network_transaction_id: rand.to_s[2..11], reason_type: 'recurring' }, network_transaction_id: rand.to_s[2..11], initiation_type: 'customer_present'))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal 'customer_present', response.params['data']['initiation_type']
  end

  def test_successful_purchase_with_reccurence_type
    @options[:pm_type] = 'gb_visa_mo_card'
    response = @gateway.purchase(@amount, @credit_card, @options.merge(recurrence_type: 'recurring'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_save_payment_method
    @options[:pm_type] = 'gb_visa_mo_card'
    response = @gateway.purchase(@amount, @credit_card, @options.merge(save_payment_method: true))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal true, response.params['data']['save_payment_method']
  end

  def test_successful_purchase_with_address
    billing_address = address(name: 'Henry Winkler', address1: '123 Happy Days Lane')

    response = @gateway.purchase(@amount, @credit_card, @options.merge(billing_address:))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_no_address
    credit_card = credit_card('4111111111111111', month: '12', year: '2035', verification_value: '345')

    options = @options.dup
    options[:billing_address] = nil
    options[:pm_type] = 'gb_mastercard_card'

    response = @gateway.purchase(@amount, credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_using_ach
    response = @gateway.purchase(100000, @check, @ach_options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_equal 'ACT', response.params['data']['status']
  end

  def test_successful_purchase_with_options
    options = @options.merge(metadata: @metadata, ewallet_id: 'ewallet_897aca846f002686e14677541f78a0f4')
    response = @gateway.purchase(100000, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Do Not Honor', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Do Not Honor', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'madeupauth')
    assert_failure response
    assert_equal 'The request tried to retrieve a payment, but the payment was not found. The request was rejected. Corrective action: Use a valid payment ID.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_successful_refund_with_options
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options.merge(metadata: @metadata))
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_partial_refund
    amount = 5000
    purchase = @gateway.purchase(amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(amount - 1050, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
    assert_equal 39.5, refund.params['data']['amount']
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'The request attempted an operation that requires a payment ID, but the payment was not found. The request was rejected. Corrective action: Use the ID of a valid payment.', response.message
  end

  def test_failed_void_with_payment_method_error
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_failure void
    assert_equal 'ERROR_PAYMENT_METHOD_TYPE_DOES_NOT_SUPPORT_PAYMENT_CANCELLATION', void.params['status']['response_code']
  end

  def test_failed_authorize_with_payment_method_type_error
    auth = @gateway_payment_redirect.authorize(@amount, @credit_card, @options.merge(pm_type: 'worng_type'))
    assert_failure auth
    assert_equal 'ERROR', auth.params['status']['status']
    assert_equal 'ERROR_GET_PAYMENT_METHOD_TYPE', auth.params['status']['response_code']
  end

  def test_failed_purchase_with_zero_amount
    response = @gateway_payment_redirect.purchase(0, @credit_card, @options)
    assert_failure response
    assert_equal 'ERROR', response.params['status']['status']
    assert_equal 'ERROR_CARD_VALIDATION_CAPTURE_TRUE', response.params['status']['response_code']
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'UNAUTHORIZED_API_CALL', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_verify_with_peso
    @options[:pm_type] = 'mx_visa_card'
    @options[:currency] = 'MXN'
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Do Not Honor', response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.params.dig('data', 'id')
    assert store.params.dig('data', 'default_payment_method')

    # 3DS authorization is required on storing a payment method for future transactions
    # This test verifies that the card id and customer id are sent with the purchase
    purchase = @gateway.purchase(100, store.authorization, @options)
    assert_match(/The request tried to use a card ID, but the cardholder has not completed the 3DS verification process./, purchase.message)
  end

  def test_successful_store_and_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert customer_id = store.params.dig('data', 'id')
    assert store.params.dig('data', 'default_payment_method')

    unstore = @gateway.unstore(store.authorization)
    assert_success unstore
    assert_equal true, unstore.params.dig('data', 'deleted')
    assert_equal customer_id, unstore.params.dig('data', 'id')
  end

  def test_failed_store
    store = @gateway.store(@declined_card, @options)
    assert_failure store
  end

  def test_failed_unstore
    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert store.params.dig('data', 'id')

    unstore = @gateway.unstore('')
    assert_failure unstore
    assert_equal 'UNAUTHORIZED_API_CALL', unstore.message
  end

  def test_invalid_login
    gateway = RapydGateway.new(secret_key: '', access_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The request did not contain the required headers for authentication. The request was rejected. Corrective action: Add authentication headers.', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(/"#{@credit_card.verification_value}"/, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
    assert_scrubbed(@gateway.options[:access_key], transcript)
  end

  def test_transcript_scrubbing_with_ach
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @ach_options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
    assert_scrubbed(@gateway.options[:access_key], transcript)
  end

  def test_successful_authorize_with_3ds_v1_options
    options = @options.merge(three_d_secure: @three_d_secure)
    options[:pm_type] = 'gb_visa_card'
    options[:three_d_secure][:version] = '1.0.2'

    response = @gateway.authorize(105000, @credit_card, options)
    assert_success response
    assert_equal 'ACT', response.params['data']['status']
    assert_equal '3d_verification', response.params['data']['payment_method_data']['next_action']
    assert response.params['data']['redirect_url']
  end

  def test_successful_authorize_with_3ds_v2_options
    options = @options.merge(three_d_secure: @three_d_secure)
    options[:pm_type] = 'gb_visa_card'

    response = @gateway.authorize(105000, @credit_card, options)
    assert_success response
    assert_equal 'ACT', response.params['data']['status']
    assert_equal '3d_verification', response.params['data']['payment_method_data']['next_action']
    assert response.params['data']['redirect_url']
  end

  def test_successful_purchase_with_3ds_v2_gateway_specific
    options = @options.merge(three_d_secure: { required: true })
    options[:pm_type] = 'gb_visa_card'

    response = @gateway.purchase(105000, @credit_card, options)
    assert_success response
    assert_equal 'ACT', response.params['data']['status']
    assert_equal '3d_verification', response.params['data']['payment_method_data']['next_action']
    assert response.params['data']['redirect_url']
    assert_match 'https://sandboxcheckout.rapyd.net/3ds-payment?token=payment_', response.params['data']['redirect_url']
  end

  def test_successful_purchase_without_3ds_v2_gateway_specific
    options = @options.merge(three_d_secure: { required: false })
    options[:pm_type] = 'gb_visa_card'
    response = @gateway.purchase(1000, @credit_card, options)
    assert_success response
    assert_equal 'CLO', response.params['data']['status']
    assert_equal 'not_applicable', response.params['data']['payment_method_data']['next_action']
    assert_equal '', response.params['data']['redirect_url']
  end

  def test_successful_authorize_with_execute_threed
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = true
    @options[:complete_payment_url] = 'http://www.google.com?param1=1&param2=2'
    options = @options.merge(pm_type: 'gb_visa_card', execute_threed: true)
    response = @gateway.authorize(105000, @credit_card, options)
    assert_success response
    assert_equal 'ACT', response.params['data']['status']
    assert_equal '3d_verification', response.params['data']['payment_method_data']['next_action']
    assert response.params['data']['redirect_url']
  ensure
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = false
  end

  def test_successful_purchase_without_cvv
    options = @options.merge({ pm_type: 'gb_visa_card', network_transaction_id: rand.to_s[2..11] })
    @credit_card.verification_value = nil
    response = @gateway.purchase(100, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_recurring_transaction_without_cvv
    @credit_card.verification_value = nil
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(stored_credential: { network_transaction_id: rand.to_s[2..11], reason_type: 'recurring' }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_empty_network_transaction_id
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(network_transaction_id: '', initiation_type: 'customer_present'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_nil_network_transaction_id
    response = @gateway.purchase(15000, @credit_card, @stored_credential_options.merge(network_transaction_id: nil, initiation_type: 'customer_present'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_payment_redirect_url
    response = @gateway_payment_redirect.purchase(@amount, @credit_card, @options.merge(pm_type: 'gb_visa_mo_card'))

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_3ds_v2_gateway_specific_payment_redirect_url
    options = @options.merge(three_d_secure: { required: true })
    options[:pm_type] = 'gb_visa_card'

    response = @gateway_payment_redirect.purchase(105000, @credit_card, options)
    assert_success response
    assert_equal 'ACT', response.params['data']['status']
    assert_equal '3d_verification', response.params['data']['payment_method_data']['next_action']
  end

  def test_successful_purchase_without_cvv_payment_redirect_url
    options = @options.merge({ pm_type: 'gb_visa_card', network_transaction_id: rand.to_s[2..11] })
    @credit_card.verification_value = nil
    response = @gateway_payment_redirect.purchase(100, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_refund_payment_redirect_url
    purchase = @gateway_payment_redirect.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_successful_subsequent_purchase_stored_credential_payment_redirect_url
    response = @gateway_payment_redirect.purchase(15000, @credit_card, @stored_credential_options.merge(stored_credential: { network_transaction_id: rand.to_s[2..11], reason_type: 'recurring' }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_fx_fields_with_currency_exchange
    @options[:pm_type] = 'gb_visa_card'
    @options[:currency] = 'GBP'
    @options[:requested_currency] = 'USD'
    @options[:fixed_side] = 'buy'

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_fx_fields_us_debit_card
    @options[:currency] = 'EUR'
    @options[:requested_currency] = 'USD'
    @options[:fixed_side] = 'buy'

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_api_version_in_request_path
    # Make a simple API call that will show the version in the response
    response = @gateway.verify(@credit_card, @options)

    # Verify the response is successful
    assert_success response

    # Check that the base URLs contain the correct version
    assert_equal 'v1', @gateway.fetch_version
    assert_match %r{/v1/$}, @gateway.test_url
    assert_match %r{/v1/$}, @gateway.payment_redirect_test
  end
end
