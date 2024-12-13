require 'test_helper'

class RemoteEbanxTest < Test::Unit::TestCase
  def setup
    @gateway = EbanxGateway.new(fixtures(:ebanx))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('5102026827345142')
    @options = {
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Maracanaú',
        state: 'CE',
        zip: '61919-230',
        country: 'BR',
        phone_number: '8522847035'
      }),
      order_id: generate_unique_id,
      document: '853.513.468-93',
      device_id: '34c376b2767',
      metadata: {
        metadata_1: 'test',
        metadata_2: 'test2'
      },
      tags: EbanxGateway::TAGS,
      soft_descriptor: 'ActiveMerchant',
      email: 'neymar@test.com',
      processing_type: 'local'
    }

    @hiper_card = credit_card('6062825624254001')
    @elo_card = credit_card('6362970000457013')

    @network_token = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      payment_cryptogram: 'network_token_example_cryptogram',
      month: 12,
      year: 2030
    )
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_hipercard
    response = @gateway.purchase(@amount, @hiper_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_elocard
    response = @gateway.purchase(@amount, @elo_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_store_elocard
    response = @gateway.purchase(@amount, @elo_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge({
      order_id: generate_unique_id,
      ip: '127.0.0.1',
      email: 'joe@example.com',
      birth_date: '10/11/1980',
      person_type: 'personal',
      payment_type_code: 'visa'
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_with_notification_url
    response = @gateway.purchase(@amount, @credit_card, @options.merge(notification_url: 'https://notify.example.com/'))
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_passing_processing_type_in_header
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ processing_type: 'local' }))

    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_as_brazil_business_with_responsible_fields
    options = @options.update(document: '32593371000110',
                              person_type: 'business',
                              responsible_name: 'Business Person',
                              responsible_document: '32593371000111',
                              responsible_birth_date: '1/11/1975')

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_as_colombian
    options = @options.merge({
      order_id: generate_unique_id,
      ip: '127.0.0.1',
      email: 'jose@example.com.co',
      birth_date: '10/11/1980',
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Medellín',
        state: 'AN',
        zip: '29269',
        country: 'CO',
        phone_number: '8522847035'
      })
    })

    response = @gateway.purchase(500, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid card or card type', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'Accepted', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid card or card type', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_failed_authorize_no_email
    response = @gateway.authorize(@amount, @declined_card, @options.except(:email))
    assert_failure response
    assert_equal 'Field payment.email is required', response.message
    assert_equal 'BP-DR-15', response.error_code
  end

  def test_successful_partial_capture_when_include_capture_amount_is_not_passed
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, { processing_type: 'local' })
    assert_success capture
  end

  # Partial capture is only available in Brazil and the EBANX Integration Team must be contacted to enable
  def test_failed_partial_capture_when_include_capture_amount_is_passed
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options.merge(include_capture_amount: true))
    assert_failure capture
    assert_equal 'Partial capture not available', capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', { processing_type: 'local' })
    assert_failure response
    assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge({ description: 'full refund' })
    assert refund = @gateway.refund(@amount, purchase.authorization, refund_options)
    assert_success refund
    assert_equal 'Accepted', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge(description: 'refund due to returned item')
    assert refund = @gateway.refund(@amount - 1, purchase.authorization, refund_options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', { processing_type: 'local' })
    assert_failure response
    assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
    assert_equal 'BP-REF-1', response.error_code
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, { processing_type: 'local' })
    assert_success void
    assert_equal 'Accepted', void.message
  end

  def test_failed_void
    response = @gateway.void('', { processing_type: 'local' })
    assert_failure response
    assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message
  end

  def test_successful_store_and_purchase_as_brazil_business
    options = @options.update(document: '32593371000110',
                              person_type: 'business',
                              responsible_name: 'Business Person',
                              responsible_document: '32593371000111',
                              responsible_birth_date: '1/11/1975')

    store = @gateway.store(@credit_card, options)
    assert_success store
    assert_equal store.authorization.split('|')[1], 'visa'

    assert purchase = @gateway.purchase(@amount, store.authorization, options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message
  end

  def test_successful_store_and_purchase_as_brazil_business_with_hipercard
    options = @options.update(document: '32593371000110',
                              person_type: 'business',
                              responsible_name: 'Business Person',
                              responsible_document: '32593371000111',
                              responsible_birth_date: '1/11/1975')

    store = @gateway.store(@hiper_card, options)
    assert_success store
    assert_equal store.authorization.split('|')[1], 'hipercard'

    assert purchase = @gateway.purchase(@amount, store.authorization, options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message
  end

  def test_failed_purchase_with_stored_card
    store = @gateway.store(@declined_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_failure purchase
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Accepted}, response.message
  end

  def test_successful_verify_for_chile
    options = @options.merge({
      order_id: generate_unique_id,
      ip: '127.0.0.1',
      email: 'jose@example.com.cl',
      birth_date: '10/11/1980',
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Medellín',
        state: 'AN',
        zip: '29269',
        country: 'CL',
        phone_number: '8522847035'
      })
    })

    response = @gateway.verify(@credit_card, options)
    assert_success response
    assert_match %r{Accepted}, response.message
  end

  def test_successful_verify_for_mexico
    options = @options.merge({
      order_id: generate_unique_id,
      ip: '127.0.0.1',
      email: 'joao@example.com.mx',
      birth_date: '10/11/1980',
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Toluca de Lerdo',
        state: 'MX',
        zip: '29269',
        country: 'MX',
        phone_number: '8522847035'
      })
    })
    response = @gateway.verify(@credit_card, options)
    assert_success response
    assert_match %r{Accepted}, response.message
  end

  def test_failed_verify
    declined_card = credit_card('6011088896715918')
    response = @gateway.verify(declined_card, @options)
    assert_failure response
    assert_match %r{Not accepted}, response.message
  end

  def test_successful_inquire
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    inquire = @gateway.inquire(purchase.authorization, { processing_type: 'local' })
    assert_success inquire

    assert_equal 'Accepted', purchase.message
  end

  def test_invalid_login
    gateway = EbanxGateway.new(integration_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Field integration_key is required}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:integration_key], transcript)
  end

  def test_successful_purchase_with_long_order_id
    options = @options.update(order_id: SecureRandom.hex(50))

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_successful_purchase_with_stored_credentials_cardholder_recurring
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'recurring',
        network_transaction_id: nil
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_unscheduled
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        network_transaction_id: nil
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_installment
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'installment',
        network_transaction_id: nil
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_installment
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'installment',
        network_transaction_id: '1234'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_unscheduled
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'unscheduled',
        network_transaction_id: '1234'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_recurring
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'recurring',
        network_transaction_id: '1234'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_not_initial
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        network_transaction_id: '1234'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_network_token
    response = @gateway.purchase(@amount, @network_token, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_failed_purchase_with_invalid_network_token
    @network_token.number = '5102026827345142'
    response = @gateway.purchase(@amount, @network_token, @options)
    assert_failure response
    assert_equal 'Invalid card or card type', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_failed_purchase_with_invalid_network_token_expire_date
    @network_token.year = nil
    response = @gateway.purchase(@amount, @network_token, @options)
    assert_failure response
    assert_equal 'Field network_token_expire_date is invalid', response.message
    assert_equal 'BP-DR-136', response.error_code
  end

  def test_network_token_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @network_token, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@network_token.number, transcript)
    assert_scrubbed(@network_token.payment_cryptogram, transcript)
  end
end
