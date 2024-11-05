require 'test_helper'
require 'securerandom'

class RemoteDecidirPlusTest < Test::Unit::TestCase
  def setup
    @gateway_purchase = DecidirPlusGateway.new(fixtures(:decidir_plus))
    @gateway_auth = DecidirPlusGateway.new(fixtures(:decidir_plus_preauth))

    @amount = 100
    @credit_card = credit_card('4484590159923090')
    @american_express = credit_card('376414000000009')
    @cabal = credit_card('5896570000000008')
    @patagonia_365 = credit_card('5046562602769006')
    @visa_debit = credit_card('4517721004856075')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      card_brand: 'visa'
    }
    @sub_payments = [
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      },
      {
        site_id: '04052018',
        installments: '1',
        amount: '1500'
      }
    ]
    @fraud_detection = {
      send_to_cs: 'false',
      channel: 'Web',
      dispatch_method: 'Store Pick Up',
      csmdds: [
        {
          code: '17',
          description: 'Campo MDD17'
        }
      ]
    }
    @aggregate_data = {
      indicator: '1',
      identification_number: '308103480',
      bill_to_pay: 'test1',
      bill_to_refund: 'test2',
      merchant_name: 'Heavenly Buffaloes',
      street: 'Sesame',
      number: '123',
      postal_code: '22001',
      category: 'yum',
      channel: '005',
      geographic_code: 'C1234',
      city: 'Ciudad de Buenos Aires',
      merchant_id: 'dec_agg',
      province: 'Buenos Aires',
      country: 'Argentina',
      merchant_email: 'merchant@mail.com',
      merchant_phone: '2678433111'
    }
  end

  def test_successful_purchase
    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, @options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase
    assert @gateway_purchase.store(@credit_card)

    response = @gateway_purchase.purchase(@amount, '', @options)
    assert_failure response
    assert_equal 'invalid_param: token', response.message
  end

  def test_successful_authorize_and_capture
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_auth.store(@credit_card, options)
    payment_reference = response.authorization

    response = @gateway_auth.authorize(@amount, payment_reference, options)
    assert_success response

    assert capture_response = @gateway_auth.capture(@amount, response.authorization, options)
    assert_success capture_response
  end

  def test_failed_authorize
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_auth.store(@declined_card, options)
    payment_reference = response.authorization

    response = @gateway_auth.authorize(@amount, payment_reference, options)
    assert_failure response
    assert_equal response.error_code, 3
  end

  def test_successful_refund
    response = @gateway_purchase.store(@credit_card)

    purchase = @gateway_purchase.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal 'approved', purchase.message

    assert refund = @gateway_purchase.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_partial_refund
    assert response = @gateway_purchase.store(@credit_card)

    purchase = @gateway_purchase.purchase(@amount, response.authorization, @options)
    assert_success purchase

    assert refund = @gateway_purchase.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway_purchase.refund(@amount, '')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_void
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_auth.store(@credit_card, options)
    payment_reference = response.authorization

    response = @gateway_auth.authorize(@amount, payment_reference, options)
    assert_success response
    assert_equal 'pre_approved', response.message
    authorization = response.authorization

    assert void_response = @gateway_auth.void(authorization)
    assert_success void_response
  end

  def test_failed_void
    assert response = @gateway_auth.void('')
    assert_failure response
    assert_equal 'not_found_error', response.message
  end

  def test_successful_verify
    assert response = @gateway_auth.verify(@credit_card, @options.merge(fraud_detection: @fraud_detection))
    assert_success response
    assert_equal 'active', response.message
  end

  def test_failed_verify
    assert response = @gateway_auth.verify(@declined_card, @options)
    assert_failure response
    assert_equal '10734: Fraud Detection Data is required', response.message
  end

  def test_successful_store
    assert response = @gateway_purchase.store(@credit_card)
    assert_success response
    assert_equal 'active', response.message
    assert_equal @credit_card.number[0..5], response.authorization.split('|')[1]
  end

  def test_successful_store_name_override
    @credit_card.name = ''
    options = { name_override: 'Rick Deckard' }
    assert response = @gateway_purchase.store(@credit_card, options)
    assert_success response
    assert_equal 'active', response.message
    assert_equal options[:name_override], response.params.dig('cardholder', 'name')
  end

  def test_successful_unstore
    customer = {
      id: 'John',
      email: 'decidir@decidir.com'
    }

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, @options.merge({ customer: }))
    assert_success response

    assert_equal 'approved', response.message
    token_id = response.params['customer_token']

    assert unstore_response = @gateway_purchase.unstore(token_id)
    assert_success unstore_response
  end

  def test_successful_purchase_with_options
    options = @options.merge(sub_payments: @sub_payments)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_fraud_detection
    options = @options.merge(fraud_detection: @fraud_detection)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal({ 'send_to_cs' => false, 'status' => nil }, response.params['fraud_detection'])
  end

  def test_successful_purchase_with_card_brand
    options = @options.merge(card_brand: 'cabal')

    assert response = @gateway_purchase.store(@cabal)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 63, response.params['payment_method_id']
  end

  def test_successful_purchase_with_card_brand_patagonia_365
    options = @options.merge(card_brand: 'patagonia_365')

    assert response = @gateway_purchase.store(@patagonia_365)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 55, response.params['payment_method_id']
  end

  def test_successful_purchase_with_payment_method_id
    options = @options.merge(payment_method_id: '63')

    assert response = @gateway_purchase.store(@cabal)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 63, response.params['payment_method_id']
  end

  def test_successful_purchase_with_establishment_name
    establishment_name = 'Heavenly Buffaloes'
    options = @options.merge(establishment_name:)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_aggregate_data
    options = @options.merge(aggregate_data: @aggregate_data)

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_additional_data_validation
    store_options = {
      card_holder_identification_type: 'dni',
      card_holder_identification_number: '44567890',
      card_holder_door_number: '348',
      card_holder_birthday: '01012017'
    }
    assert response = @gateway_purchase.store(@credit_card, store_options)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, @options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_failed_purchase_with_payment_method_id
    options = @options.merge(payment_method_id: '1')

    assert response = @gateway_purchase.store(@cabal)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_failure response
  end

  def test_successful_purchase_with_debit
    options = @options.merge(debit: 'true', card_brand: 'visa')

    assert response = @gateway_purchase.store(@visa_debit)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_success response
    assert_equal 31, response.params['payment_method_id']
  end

  def test_failed_purchase_with_debit
    options = @options.merge(debit: 'true', card_brand: 'visa')

    assert response = @gateway_purchase.store(@credit_card)
    payment_reference = response.authorization

    response = @gateway_purchase.purchase(@amount, payment_reference, options)
    assert_failure response
    assert_equal 'invalid_param: bin', response.message
  end

  def test_invalid_login
    gateway = DecidirPlusGateway.new(public_key: '12345', private_key: 'abcde')

    response = gateway.store(@credit_card, @options)
    assert_failure response
    assert_match %r{Invalid authentication credentials}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway_purchase) do
      @gateway_purchase.store(@credit_card, @options)
    end
    transcript = @gateway_purchase.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway_purchase.options[:public_key], transcript)
    assert_scrubbed(@gateway_purchase.options[:private_key], transcript)
  end
end
