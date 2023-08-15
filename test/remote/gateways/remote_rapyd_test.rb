require 'test_helper'

class RemoteRapydTest < Test::Unit::TestCase
  def setup
    @gateway = RapydGateway.new(fixtures(:rapyd))

    @amount = 100
    @credit_card = credit_card('4111111111111111', first_name: 'Ryan', last_name: 'Reynolds', month: '12', year: '2035', verification_value: '345')
    @declined_card = credit_card('4111111111111105')
    @check = check
    @options = {
      pm_type: 'us_debit_visa_card',
      currency: 'USD',
      complete_payment_url: 'www.google.com',
      error_payment_url: 'www.google.com',
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
      'array_of_objects': [
        { 'name': 'John Doe' },
        { 'type': 'customer' }
      ],
      'array_of_strings': %w[
        color
        size
      ],
      'number': 1234567890,
      'object': {
        'string': 'person'
      },
      'string': 'preferred',
      'Boolean': true
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
    @options[:currency] = 'GBP'
    @options[:pm_type] = 'gb_visa_card'
    @options[:complete_payment_url] = 'https://www.rapyd.net/platform/collect/online/'
    @options[:error_payment_url] = 'https://www.rapyd.net/platform/collect/online/'

    # Rapyd requires a random int between 10 and 15 digits for NTID
    response = @gateway.purchase(15000, @credit_card, @options.merge({ stored_credential: { network_transaction_id: rand.to_s[2..11], reason_type: 'recurring' } }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_address
    billing_address = address(name: 'Henry Winkler', address1: '123 Happy Days Lane')

    response = @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: billing_address))
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
    options = @options.merge(metadata: @metadata, ewallet_id: 'ewallet_1a867a32b47158b30a8c17d42f12f3f1')
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
    assert_equal 'ERROR_PAYMENT_METHOD_TYPE_DOES_NOT_SUPPORT_PAYMENT_CANCELLATION', void.error_code
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
    assert_scrubbed(@credit_card.verification_value, transcript)
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
end
