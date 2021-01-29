require 'test_helper'

class RemoteDecidirTest < Test::Unit::TestCase
  def setup
    @gateway_for_purchase = DecidirGateway.new(fixtures(:decidir_purchase))
    @gateway_for_auth = DecidirGateway.new(fixtures(:decidir_authorize))

    @amount = 100
    @credit_card = credit_card('4507990000004905')
    @master_card_credit_card = credit_card('5299910010000015')
    @amex_credit_card = credit_card('373953192351004')
    @diners_club_credit_card = credit_card('36463664750005')
    @cabal_credit_card = credit_card('5896570000000008')
    @naranja_credit_card = credit_card('5895627823453005')
    @declined_card = credit_card('4000300011112220')
    @options = {
      order_id: SecureRandom.uuid,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_master_card
    response = @gateway_for_purchase.purchase(@amount, @master_card_credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_amex
    response = @gateway_for_purchase.purchase(@amount, @amex_credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
    assert response.authorization
  end

  # This test is currently failing.
  # Decidir hasn't been able to provide a valid Diners Club test card number.
  #
  # def test_successful_purchase_with_diners_club
  #   response = @gateway_for_purchase.purchase(@amount, @diners_club_credit_card, @options)
  #   assert_success response
  #   assert_equal 'approved', response.message
  #   assert response.authorization
  # end

  def test_successful_purchase_with_cabal
    response = @gateway_for_purchase.purchase(@amount, @cabal_credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_naranja
    response = @gateway_for_purchase.purchase(@amount, @naranja_credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_more_options
    options = {
      ip: '127.0.0.1',
      email: 'joe@example.com',
      card_holder_door_number: '1234',
      card_holder_birthday: '01011980',
      card_holder_identification_type: 'dni',
      card_holder_identification_number: '123456',
      establishment_name: 'Heavenly Buffaloes',
      device_unique_identifier: '1',
      fraud_detection: {
        send_to_cs: false,
        channel: 'Web',
        dispatch_method: 'Store Pick Up',
        csmdds: [
          {
            code: 17,
            description: 'Campo MDD17'
          }
        ],
        device_unique_id: '1',
        bill_to: {
          postal_code: '12345',
          last_name: 'Smith',
          country: 'US',
          street1: '123 Mockingbird Lane',
          state: 'TN',
          email: 'dootdoot@hotmail.com',
          customer_id: '111111',
          phone_number: '555-5555',
          first_name: 'Joe',
          city: 'Pantsville'
        },
        customer_in_site: {
          password: '',
          is_guest: false,
          street: '123 Mockingbird Lane',
          cellphone_number: '555-1212',
          num_of_transactions: 48,
          date_of_birth: '8-4-80',
          days_in_site: 105
        },
        purchase_totals: {
          currency: 'USD',
          amount: 100
        }
      },
      installments: '12',
      site_id: '99999999'
    }

    response = @gateway_for_purchase.purchase(@amount, credit_card('4509790112684851'), @options.merge(options))
    assert_success response
    assert_equal 'approved', response.message
    assert_equal 'Heavenly Buffaloes', response.params['establishment_name']
    assert_equal '99999999', response.params['site_id']
    assert_equal({ 'status' => nil }, response.params['fraud_detection'])
    assert response.authorization
  end

  def test_failed_purchase_with_bad_csmdds
    options = {
      fraud_detection: {
        send_to_cs: false,
        channel: 'Web',
        dispatch_method: 'Store Pick Up',
        csmdds: [
          {
            codee: 17,
            descriptione: 'Campo MDD17'
          }
        ]
      }
    }

    response = @gateway_for_purchase.purchase(@amount, credit_card('4509790112684851'), @options.merge(options))
    assert_failure response
    assert_equal 'param_required: fraud_detection.csmdds.[0].code, param_required: fraud_detection.csmdds.[0].description', response.message
    assert_equal(nil, response.params['fraud_detection'])
  end

  def test_failed_purchase
    response = @gateway_for_purchase.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'COMERCIO INVALIDO | invalid_card', response.message
    assert_equal '3, config_error', response.error_code
    assert_match Gateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_failed_purchase_with_invalid_field
    response = @gateway_for_purchase.purchase(@amount, @declined_card, @options.merge(installments: -1))
    assert_failure response
    assert_equal 'invalid_param: installments', response.message
    assert_equal 'invalid_request_error', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'pre_approved', auth.message
    assert auth.authorization

    assert capture = @gateway_for_auth.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'approved', capture.message
    assert capture.authorization
  end

  def test_failed_authorize
    response = @gateway_for_auth.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'PEDIR AUTORIZACION | request_authorization_card', response.message
    assert_match 'call_issuer', response.error_code
  end

  def test_failed_partial_capture
    auth = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway_for_auth.capture(1, auth.authorization)
    assert_failure capture
    assert_equal 'amount: Amount out of ranges: 80 - 105', capture.message
    assert_equal 'invalid_request_error', capture.error_code
    assert_nil capture.authorization
  end

  def test_failed_capture
    response = @gateway_for_auth.capture(@amount, '')

    assert_equal 'not_found_error', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    purchase = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway_for_purchase.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
    assert refund.authorization
  end

  def test_partial_refund
    purchase = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway_for_purchase.refund(@amount - 1, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
    assert refund.authorization
  end

  def test_failed_refund
    response = @gateway_for_purchase.refund(@amount, '')
    assert_failure response
    assert_equal 'not_found_error', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_void
    auth = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway_for_auth.void(auth.authorization)
    assert_success void
    assert_equal 'approved', void.message
    assert void.authorization
  end

  def test_failed_void
    response = @gateway_for_auth.void('')
    assert_failure response
    assert_equal 'not_found_error', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_verify
    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_success response
    assert_match %r{pre_approved}, response.message
  end

  def test_failed_verify
    response = @gateway_for_auth.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{PEDIR AUTORIZACION | request_authorization_card}, response.message
  end

  def test_invalid_login_without_api_key
    gateway = DecidirGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{No API key found in request}, response.message
  end

  def test_invalid_login
    gateway = DecidirGateway.new(api_key: 'xxxxxxx')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid authentication credentials}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway_for_purchase) do
      @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway_for_purchase.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway_for_purchase.options[:api_key], transcript)
  end
end
