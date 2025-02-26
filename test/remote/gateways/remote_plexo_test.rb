require 'test_helper'

class RemotePlexoTest < Test::Unit::TestCase
  def setup
    @gateway = PlexoGateway.new(fixtures(:plexo))

    @amount = 100
    @credit_card = credit_card('5555555555554444', month: '12', year: Time.now.year + 1, verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')
    @declined_card = credit_card('5555555555554445')
    @options = {
      email: 'snavatta@plexo.com.uy',
      ip: '127.0.0.1',
      items: [
        {
          name: 'prueba',
          description: 'prueba desc',
          quantity: '1',
          price: '100',
          discount: '0'
        }
      ],
      amount_details: {
        tip_amount: '5'
      },
      identification_type: '1',
      identification_value: '123456',
      billing_address: address,
      invoice_number: '12345abcde'
    }

    @cancel_options = {
      description: 'Test desc',
      reason: 'requested by client'
    }

    @network_token_credit_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      first_name: 'Santiago', last_name: 'Navatta',
        brand: 'Mastercard',
        payment_cryptogram: 'UnVBR0RlYm42S2UzYWJKeWJBdWQ=',
        number: '5555555555554444',
        source: :network_token,
        month: '12',
        year: Time.now.year
    })

    @decrypted_network_token = NetworkTokenizationCreditCard.new(
      {
        first_name: 'Joe', last_name: 'Doe',
        brand: 'visa',
        payment_cryptogram: 'UnVBR0RlYm42S2UzYWJKeWJBdWQ=',
        number: '5555555555554444',
        source: :network_token,
        month: '12',
        year: Time.now.year
      }
    )
  end

  def test_successful_purchase_with_network_token
    response = @gateway.purchase(@amount, @decrypted_network_token, @options.merge({ invoice_number: '12345abcde' }))
    assert_success response
    assert_equal 'You have been mocked.', response.message
  end

  def test_successful_inquire_with_payment_id
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    auth = response.authorization
    inquire = @gateway.inquire(auth, @options)
    assert_success inquire
    assert_match auth, response.params['id']
  end

  def test_successful_purchase_and_inquire_with_payment_id
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    purchase_transaction = response.params
    inquire = @gateway.inquire(response.authorization, @options)
    assert_success inquire
    inquire_transaction = inquire.params
    assert_equal purchase_transaction['id'], inquire_transaction['id']
    assert_equal purchase_transaction['referenceId'], inquire_transaction['referenceId']
    assert_equal purchase_transaction['status'], inquire_transaction['status']
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_finger_print
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ finger_print: 'USABJHABSFASNJKN123532' }))
    assert_success response
  end

  def test_successful_purchase_with_invoice_number
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ invoice_number: '12345abcde' }))
    assert_success response
    assert_equal '12345abcde', response.params['invoiceNumber']
  end

  def test_successfully_send_merchant_id
    # ensures that we can set and send the merchant_id and get a successful response
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ merchant_id: 3243 }))
    assert_success response
    assert_equal 3243, response.params['merchant']['id']

    # ensures that we can set and send the merchant_id and expect a failed response for invalid merchant_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ merchant_id: 1234 }))
    assert_failure response
    assert_equal 'The requested Merchant was not found.', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'denied', response.params['status']
    assert_equal '10', response.error_code
  end

  def test_successful_authorize_with_metadata
    meta = {
      custom_one: 'my field 1'
    }
    auth = @gateway.authorize(@amount, @credit_card, @options.merge({ metadata: meta }))
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '10', response.error_code
    assert_equal 'denied', response.params['status']
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth

    response = @gateway.capture(@amount, auth.authorization)
    assert_failure response
    assert_equal 'The selected payment state is not valid.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @cancel_options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge({ refund_type: 'partial-refund' }))
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization, @cancel_options.merge({ type: 'partial-refund' }))
    assert_success refund
  end

  def test_failed_refund
    auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth

    response = @gateway.refund(@amount, auth.authorization, @cancel_options)
    assert_failure response
    assert_equal 'The selected payment state is not valid.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @cancel_options)
    assert_success void
  end

  def test_failed_void
    auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth

    response = @gateway.void(auth.authorization, @cancel_options)
    assert_failure response
    assert_equal 'The selected payment state is not valid.', response.message
  end

  # for verify tests: sometimes those fails but re-running after
  # few seconds they can works

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_custom_amount
    response = @gateway.verify(@credit_card, @options.merge({ verify_amount: '400' }))
    assert_success response
  end

  def test_successful_verify_with_invoice_number
    response = @gateway.verify(@credit_card, @options.merge({ invoice_number: '12345abcde' }))
    assert_success response
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
  end

  def test_invalid_login
    gateway = PlexoGateway.new(client_id: '', api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  def test_successful_purchase_passcard
    credit_card = credit_card('6280260025383009', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_edenred
    credit_card = credit_card('6374830000000823', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_anda
    credit_card = credit_card('6031991248204901', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
  end

  # This test is omitted until Plexo confirms that the transaction will indeed
  # be declined as indicated in the documentation.
  def test_successful_purchase_and_declined_refund_anda
    omit
    credit_card = credit_card('6031997614492616', month: '12', year: '2024',
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @cancel_options)
    assert_failure refund
    assert_equal 'An internal error occurred. Contact support.', refund.message
  end

  # This test is omitted until Plexo confirms that the transaction will indeed
  # be declined as indicated in the documentation.
  def test_successful_purchase_and_declined_cancellation_anda
    omit
    credit_card = credit_card('6031998427187914', month: '12', year: '2024',
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, @cancel_options)
    assert_failure void
  end

  def test_successful_purchase_tarjetad
    credit_card = credit_card('6018287227431046', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
  end

  def test_failure_purchase_tarjetad
    credit_card = credit_card('6018282227431033', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_failure response
    assert_equal 'denied', response.params['status']
    assert_equal '10', response.error_code
  end

  def test_successful_purchase_sodexo
    credit_card = credit_card('5058645584812145', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
  end

  # This test is omitted until Plexo confirms that the transaction will indeed
  # be declined as indicated in the documentation.
  def test_successful_purchase_and_declined_refund_sodexo
    omit
    credit_card = credit_card('5058647731868699', month: '12', year: '2024',
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @cancel_options)
    assert_failure refund
    assert_equal 'An internal error occurred. Contact support.', refund.message
  end

  def test_successful_purchase_and_declined_cancellation_sodexo
    credit_card = credit_card('5058646599260130', month: '12', year: Time.now.year + 1,
      verification_value: '111', first_name: 'Santiago', last_name: 'Navatta')

    purchase = @gateway.purchase(@amount, credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, @cancel_options)
    assert_failure void
  end
end
