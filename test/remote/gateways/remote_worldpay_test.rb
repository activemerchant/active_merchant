require 'test_helper'

class RemoteWorldpayTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayGateway.new(fixtures(:world_pay_gateway))
    @cftgateway = WorldpayGateway.new(fixtures(:world_pay_gateway_cft))

    @amount = 100
    @year = (Time.now.year + 2).to_s[-2..-1].to_i
    @credit_card = credit_card('4111111111111111')
    @amex_card = credit_card('3714 496353 98431')
    @elo_credit_card = credit_card(
      '4514 1600 0000 0008',
      month: 10,
      year: 2020,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo'
    )
    @credit_card_with_two_digits_year = credit_card(
      '4111111111111111',
      month: 10,
      year: @year
    )
    @cabal_card = credit_card('6035220000000006')
    @naranja_card = credit_card('5895620000000002')
    @sodexo_voucher = credit_card('6060704495764400', brand: 'sodexo')
    @declined_card = credit_card('4111111111111111', first_name: nil, last_name: 'REFUSED')
    @threeDS_card = credit_card('4111111111111111', first_name: nil, last_name: 'doot')
    @threeDS2_card = credit_card('4111111111111111', first_name: nil, last_name: '3DS_V2_FRICTIONLESS_IDENTIFIED')
    @threeDS2_challenge_card = credit_card('4000000000001091', first_name: nil, last_name: 'challenge-me-plz')
    @threeDS_card_external_MPI = credit_card('4444333322221111', first_name: 'AA', last_name: 'BD')
    @nt_credit_card = network_tokenization_credit_card(
      '4895370015293175',
      brand: 'visa',
      eci: '07',
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @visa_nt_credit_card_without_eci = network_tokenization_credit_card(
      '4895370015293175',
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @mastercard_nt_credit_card_without_eci = network_tokenization_credit_card(
      '5555555555554444',
      source: :network_token,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    @options = {
      order_id: generate_unique_id,
      email: 'wow@example.com',
      ip: '127.0.0.1'
    }

    @level_two_data = {
      level_2_data: {
        invoice_reference_number: 'INV12233565',
        customer_reference: 'CUST00000101',
        card_acceptor_tax_id: 'VAT1999292',
        tax_amount: '20',
        ship_from_postal_code:  '43245'
      }
    }

    @level_three_data = {
      level_3_data: {
        customer_reference: 'CUST00000102',
        card_acceptor_tax_id: 'VAT1999285',
        tax_amount: '20',
        discount_amount: '1',
        shipping_amount: '50',
        duty_amount: '20',
        line_items: [{
          description: 'Laptop 14',
          product_code: 'LP00125',
          commodity_code: 'COM00125',
          quantity: '2',
          unit_cost: '1500',
          unit_of_measure: 'each',
          discount_amount: '200',
          tax_amount: '500',
          total_amount: '3300'
        },
                     {
                       description: 'Laptop 15',
                              product_code: 'LP00125',
                              commodity_code: 'COM00125',
                              quantity: '2',
                              unit_cost: '1500',
                              unit_of_measure: 'each',
                              discount_amount: '200',
                              tax_amount: '500',
                              total_amount: '3300'
                     }]
      }
    }

    @store_options = {
      customer: generate_unique_id,
      email: 'wow@example.com'
    }

    @sub_merchant_options = {
      sub_merchant_data: {
        pf_id: '12345678901',
        sub_name: 'Example Shop',
        sub_id: '1234567',
        sub_street: '123 Street',
        sub_city: 'San Francisco',
        sub_state: 'CA',
        sub_country_code: '840',
        sub_postal_code: '94101',
        sub_tax_id: '987-65-4321'
      }
    }

    @apple_pay_network_token = network_tokenization_credit_card(
      '4895370015293175',
      month: 10,
      year: Time.new.year + 2,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      payment_cryptogram: 'abc1234567890',
      eci: '07',
      transaction_id: 'abc123',
      source: :apple_pay
    )

    @google_pay_network_token = network_tokenization_credit_card(
      '4444333322221111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: Time.new.year + 2,
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )

    @google_pay_network_token_without_eci = network_tokenization_credit_card(
      '4444333322221111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '01',
      year: Time.new.year + 2,
      source: :google_pay,
      transaction_id: '123456789',
      eci: '05'
    )

    @aft_options = {
      account_funding_transaction: true,
      aft_type: 'A',
      aft_payment_purpose: '01',
      aft_sender_account_type: '02',
      aft_sender_account_reference: '4111111111111112',
      aft_sender_full_name: {
        first: 'First',
        middle: 'Middle',
        last: 'Sender'
      },
      aft_sender_funding_address: {
        address1: '123 Sender St',
        address2: 'Apt 1',
        postal_code: '12345',
        city: 'Senderville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_account_type: '03',
      aft_recipient_account_reference: '4111111111111111',
      aft_recipient_full_name: {
        first: 'First',
        middle: 'Middle',
        last: 'Recipient'
      },
      aft_recipient_funding_address: {
        address1: '123 Recipient St',
        address2: 'Apt 1',
        postal_code: '12345',
        city: 'Recipientville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_funding_data: {
        telephone_number: '123456789',
        birth_date: {
          day_of_month: '01',
          month: '01',
          year: '1980'
        }
      }
    }

    @aft_less_options = {
      account_funding_transaction: true,
      aft_type: 'A',
      aft_payment_purpose: '01',
      aft_sender_account_type: '02',
      aft_sender_account_reference: '4111111111111112',
      aft_sender_full_name: {
        first: 'First',
        last: 'Sender'
      },
      aft_sender_funding_address: {
        address1: '123 Sender St',
        postal_code: '12345',
        city: 'Senderville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_account_type: '03',
      aft_recipient_account_reference: '4111111111111111',
      aft_recipient_full_name: {
        first: 'First',
        last: 'Recipient'
      },
      aft_recipient_funding_address: {
        address1: '123 Recipient St',
        postal_code: '12345',
        city: 'Recipientville',
        state: 'NC',
        country_code: 'US'
      },
      aft_recipient_funding_data: {
        telephone_number: '123456789',
        birth_date: {
          day_of_month: '01',
          month: '01',
          year: '1980'
        }
      }
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_token
    assert response = @gateway.purchase(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_token_with_shopper_ip_address
    assert response = @gateway.purchase(@amount, @nt_credit_card, @options.merge(ip: '127.0.0.1'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_token_and_stored_credentials
    stored_credential_params = stored_credential(:initial, :unscheduled, :merchant)

    assert response = @gateway.purchase(@amount, @nt_credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_token_without_eci_visa
    assert response = @gateway.purchase(@amount, @visa_nt_credit_card_without_eci, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_network_token_without_eci_mastercard
    assert response = @gateway.purchase(@amount, @mastercard_nt_credit_card_without_eci, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_card_holder_name_apple_pay
    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert_success response
    assert_equal @amount, response.params['amount_value'].to_i
    assert_equal 'GBP', response.params['amount_currency_code']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_card_holder_name_google_pay
    response = @gateway.authorize(@amount, @google_pay_network_token, @options)
    assert_success response
    assert_equal @amount, response.params['amount_value'].to_i
    assert_equal 'GBP', response.params['amount_currency_code']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_without_eci_google_pay
    response = @gateway.authorize(@amount, @google_pay_network_token_without_eci, @options)
    assert_success response
    assert_equal @amount, response.params['amount_value'].to_i
    assert_equal 'GBP', response.params['amount_currency_code']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_default_eci_google_pay
    response = @gateway.authorize(@amount, @google_pay_network_token_without_eci, @options.merge({ use_default_eci: true }))
    assert_success response
    assert_equal @amount, response.params['amount_value'].to_i
    assert_equal 'GBP', response.params['amount_currency_code']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_google_pay_pan_only
    response = @gateway.authorize(@amount, @credit_card, @options.merge!(wallet_type: :google_pay))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_purchase_with_google_pay_pan_only
    assert auth = @gateway.purchase(@amount, @credit_card, @options.merge!(wallet_type: :google_pay))
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
  end

  def test_successful_authorize_with_void_google_pay_pan_only
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge!(wallet_type: :google_pay))
    assert_success auth
    assert_equal 'authorize', auth.params['action']
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_success capture
    assert void = @gateway.void(auth.authorization, @options.merge(authorization_validated: true))
    assert_success void
  end

  def test_successful_authorize_without_card_holder_name_apple_pay
    @apple_pay_network_token.first_name = ''
    @apple_pay_network_token.last_name = ''

    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)

    assert_success response
    assert_equal 'authorize', response.params['action']
    assert_equal @amount, response.params['amount_value'].to_i
    assert_equal 'GBP', response.params['amount_currency_code']
    assert_equal 'SUCCESS', response.message
  end

  def test_unsucessfull_authorize_without_token_number_apple_pay
    @apple_pay_network_token.number = nil
    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)

    assert_failure response
    assert_equal response.error_code, '2'
    assert_match "Missing required elements 'tokenNumber'", response.message
  end

  def test_unsucessfull_authorize_with_token_number_as_empty_string_apple_pay
    @apple_pay_network_token.number = ''
    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)

    assert_failure response
    assert_equal response.error_code, '2'
    assert_match "Missing required elements 'tokenNumber'", response.message
  end

  def test_unsucessfull_authorize_with_invalid_token_number_apple_pay
    @apple_pay_network_token.first_name = 'REFUSED' # Magic value for testing purposes
    @apple_pay_network_token.last_name = ''

    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert_failure response
    assert_equal 'REFUSED', response.message
  end

  def test_unsuccessful_authorize_with_overdue_expire_date_apple_pay
    @apple_pay_network_token.month = 10
    @apple_pay_network_token.year = 2019

    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert_failure response
    assert_equal 'Invalid payment details : Expiry date = 10/2019', response.message
  end

  def test_unsuccessful_authorize_without_expire_date_apple_pay
    @apple_pay_network_token.month = nil
    @apple_pay_network_token.year = nil

    response = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert_failure response
    assert_match(/of type NMTOKEN must be a name token/, response.message)
  end

  def test_purchase_with_apple_pay_card_apple_pay
    assert auth = @gateway.purchase(@amount, @apple_pay_network_token, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization
  end

  def test_successful_authorize_with_void_apple_pay
    assert auth = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert_success auth
    assert_equal 'authorize', auth.params['action']
    assert_equal @amount, auth.params['amount_value'].to_i
    assert_equal 'GBP', auth.params['amount_currency_code']
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_success capture
    assert void = @gateway.void(auth.authorization, @options.merge(authorization_validated: true))
    assert_success void
  end

  def test_successful_purchase_with_refund_apple_pay
    assert auth = @gateway.purchase(@amount, @apple_pay_network_token, @options)
    assert_success auth
    assert_equal 'capture', auth.params['action']
    assert_equal @amount, auth.params['amount_value'].to_i
    assert_equal 'GBP', auth.params['amount_currency_code']
    assert auth.authorization
    assert refund = @gateway.refund(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_success refund
  end

  def test_successful_store_apple_pay
    assert response = @gateway.store(@apple_pay_network_token, @store_options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match response.params['payment_token_id'], response.authorization
    assert_match 'shopper', response.authorization
    assert_match @store_options[:customer], response.authorization
  end

  def test_successful_purchase_with_elo
    assert response = @gateway.purchase(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_two_digits_expiration_year
    assert response = @gateway.purchase(@amount, @credit_card_with_two_digits_year, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_cabal
    response = @gateway.purchase(@amount, @cabal_card, @options.merge(currency: 'ARS'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_naranja
    response = @gateway.purchase(@amount, @naranja_card, @options.merge(currency: 'ARS'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_skipping_capture
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_capture: true))
    assert_success response
    assert response.responses.length == 1
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_avs_and_cvv
    card = credit_card('4111111111111111', verification_value: 555)
    assert response = @gateway.authorize(@amount, card, @options.merge(billing_address: address.update(zip: 'CCCC')))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match %r{Street address does not match, but 5-digit postal code matches}, response.avs_result['message']
    assert_match %r{CVV matches}, response.cvv_result['message']
  end

  def test_successful_authorize_with_sub_merchant_data
    options = @options.merge(@sub_merchant_options)
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_3ds2_authorize
    options = @options.merge({ execute_threed: true, three_ds_version: '2.0' })
    assert response = @gateway.authorize(@amount, @threeDS2_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_3ds2_authorize_with_browser_size
    options = @options.merge({ execute_threed: true, three_ds_version: '2.0', browser_size: '390x400' })
    assert response = @gateway.authorize(@amount, @threeDS2_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_risk_data
    options = @options.merge({ execute_threed: true, three_ds_version: '2.0', risk_data: })
    assert response = @gateway.authorize(@amount, @threeDS2_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_sub_merchant_data
    options = @options.merge(@sub_merchant_options)
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_hcg_additional_data
    @options[:hcg_additional_data] = {
      key1: 'value1',
      key2: 'value2',
      key3: 'value3'
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_equal 'REFUSED', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_authorize_and_capture_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
    assert reference = auth.authorization
    @options[:order_id] = generate_unique_id

    assert auth = @gateway.authorize(@amount, reference, @options)
    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_authorize_and_purchase_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
    assert reference = auth.authorization

    @options[:order_id] = generate_unique_id
    assert auth = @gateway.authorize(@amount, reference, @options)

    @options[:order_id] = generate_unique_id
    assert capture = @gateway.purchase(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_authorize_and_purchase_with_instalments
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(instalment: 3))
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_authorize_with_3ds
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id:,
        ip: '127.0.0.1',
        cookie: 'machine=32423423'
      }
    )
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert first_message.test?
    assert first_message.success?
    refute first_message.authorization.blank?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  # Ensure the account is configured to use this feature to proceed successfully
  def test_marking_3ds_purchase_as_moto
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(metadata: { manual_entry: true }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_with_3ds2_challenge
    session_id = generate_unique_id
    options = @options.merge(
      # inserted this @aft_otpions for testing during review if desired, did not want to duplicate
      # this entire test with just this addtion, will remove after review
      @aft_options,
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id:,
        ip: '127.0.0.1'
      }
    )
    assert response = @gateway.authorize(@amount, @threeDS2_challenge_card, options)
    assert response.test?
    refute response.authorization.blank?
    assert response.success?
    refute response.params['cookie'].blank?
    refute response.params['session_id'].blank?
  end

  def test_successful_auth_and_capture_with_normalized_stored_credential
    stored_credential_params = stored_credential(:initial, :unscheduled, :merchant)

    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:order_id] = generate_unique_id
    @options[:stored_credential] = stored_credential(:used, :installment, :merchant, network_transaction_id: auth.params['transaction_identifier'])

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_normalized_recurring_stored_credential
    stored_credential_params = stored_credential(:initial, :recurring, :merchant)

    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:order_id] = generate_unique_id
    @options[:stored_credential] = stored_credential(:used, :recurring, :merchant, network_transaction_id: auth.params['transaction_identifier'])

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_gateway_specific_stored_credentials
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(stored_credential_usage: 'FIRST'))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    options = @options.merge(
      order_id: generate_unique_id,
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'UNSCHEDULED',
      stored_credential_transaction_id: auth.params['transaction_identifier']
    )
    assert next_auth = @gateway.authorize(@amount, @credit_card, options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_gateway_specific_recurring_stored_credentials
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(stored_credential_usage: 'FIRST', stored_credential_initiated_reason: 'RECURRING'))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    options = @options.merge(
      order_id: generate_unique_id,
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'RECURRING',
      stored_credential_transaction_id: auth.params['transaction_identifier']
    )
    assert next_auth = @gateway.authorize(@amount, @credit_card, options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_recurring_purchase_with_apple_pay_credentials
    stored_credential_params = stored_credential(:initial, :recurring, :merchant)
    assert auth = @gateway.authorize(@amount, @apple_pay_network_token, @options.merge({ stored_credential: stored_credential_params }))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:order_id] = generate_unique_id
    @options[:stored_credential] = stored_credential(:used, :recurring, :merchant, network_transaction_id: auth.params['transaction_identifier'])

    assert next_auth = @gateway.authorize(@amount, @apple_pay_network_token, @options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_authorize_with_3ds_with_normalized_stored_credentials
    session_id = generate_unique_id
    stored_credential_params = stored_credential(:initial, :unscheduled, :merchant)
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id:,
        ip: '127.0.0.1',
        cookie: 'machine=32423423',
        stored_credential: stored_credential_params
      }
    )
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert first_message.test?
    refute first_message.authorization.blank?
    assert first_message.success?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  def test_successful_authorize_with_3ds_with_gateway_specific_stored_credentials
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id:,
        ip: '127.0.0.1',
        cookie: 'machine=32423423',
        stored_credential_usage: 'FIRST'
      }
    )
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert first_message.test?
    refute first_message.authorization.blank?
    assert first_message.success?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  def test_successful_purchase_with_level_two_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_two_data))
    assert_success response
    assert_equal true, response.params['ok']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_level_two_fields_and_sales_tax_zero
    @level_two_data[:level_2_data][:tax_amount] = 0
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_two_data))
    assert_success response
    assert_equal true, response.params['ok']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_level_three_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_three_data))
    assert_success response
    assert_equal true, response.params['ok']
    assert_equal 'SUCCESS', response.message
  end

  def test_unsuccessful_purchase_level_three_data_without_item_mastercard
    @level_three_data[:level_3_data][:line_items] = [{
    }]
    @credit_card.brand = 'master'
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_three_data))
    assert_failure response
    assert_equal response.error_code, '2'
    assert_equal response.params['error'].gsub(/\"+/, ''), 'The content of element type item must match (description,productCode?,commodityCode?,quantity?,unitCost?,unitOfMeasure?,itemTotal?,itemTotalWithTax?,itemDiscountAmount?,itemTaxRate?,lineDiscountIndicator?,itemLocalTaxRate?,itemLocalTaxAmount?,taxAmount?,categories?,pageURL?,imageURL?).'
  end

  def test_successful_purchase_with_level_two_and_three_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@level_two_data, @level_three_data))
    assert_success response
    assert_equal true, response.params['ok']
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_custom_string_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(custom_string_fields: { custom_string_field_1: 'testvalue1', custom_string_field_2: 'testvalue2' }))
    assert_success response
    assert_equal true, response.params['ok']
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase_with_blank_custom_string_field
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(custom_string_fields: { custom_string_field_1: '' }))
    assert_failure response

    assert_equal "The tag 'customStringField1' cannot be empty", response.message
  end

  # Fails currently because the sandbox doesn't actually validate the stored_credential options
  # def test_failed_authorize_with_bad_stored_cred_options
  #   assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(stored_credential_usage: 'FIRST'))
  #   assert_success auth
  #   assert auth.authorization
  #   assert auth.params['scheme_response']
  #   assert auth.params['transaction_identifier']
  #
  #   assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
  #   assert_success capture
  #
  #   options = @options.merge(
  #     order_id: generate_unique_id,
  #     stored_credential_usage: 'MEH',
  #     stored_credential_initiated_reason: 'BLAH',
  #     stored_credential_transaction_id: 'nah'
  #   )
  #   assert next_auth = @gateway.authorize(@amount, @credit_card, options)
  #   assert_failure next_auth
  # end

  def test_failed_authorize_with_3ds
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        session_id:,
        ip: '127.0.0.1',
        cookie: 'machine=32423423'
      }
    )
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert_match %r{missing info for 3D-secure transaction}i, first_message.message
    assert first_message.test?
    assert first_message.params['issuer_url'].blank?
    assert first_message.params['pa_request'].blank?
  end

  def test_3ds_version_1_parameters_pass_thru
    options = @options.merge(
      {
        three_d_secure: {
          version: '1.0.2',
          xid: 'z9UKb06xLziZMOXBEmWSVA1kwG0=',
          cavv: 'MAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          eci: '05'
        }
      }
    )

    assert response = @gateway.authorize(@amount, @threeDS_card_external_MPI, @options.merge(options))
    assert response.test?
    assert response.success?
    assert response.params['last_event'] || response.params['ok']
  end

  def test_3ds_version_2_parameters_pass_thru
    options = @options.merge(
      {
        three_d_secure: {
          version: '2.1.0',
          ds_transaction_id: 'c5b808e7-1de1-4069-a17b-f70d3b3b1645',
          cavv: 'MAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          eci: '05'
        }
      }
    )

    assert response = @gateway.authorize(@amount, @threeDS_card_external_MPI, @options.merge(options))
    assert response.test?
    assert response.success?
    assert response.params['last_event'] || response.params['ok']
  end

  def test_3ds_version_2_parameters_for_nt
    options = @options.merge(
      {
        three_d_secure: {
          version: '2.1.0',
          ds_transaction_id: 'c5b808e7-1de1-4069-a17b-f70d3b3b1645',
          cavv: 'MAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          eci: '05'
        }
      }
    )

    assert response = @gateway.authorize(@amount, @nt_credit_card, @options.merge(options))
    assert response.test?
    assert response.success?
    assert response.params['last_event'] || response.params['ok']
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'bogus')
    assert_failure response
    assert_equal 'Could not find payment for order', response.message
  end

  def test_billing_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(billing_address: address))
  end

  def test_partial_address
    billing_address = address
    billing_address.delete(:address1)
    billing_address.delete(:zip)
    billing_address.delete(:country)
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(billing_address:))
  end

  def test_state_omitted
    billing_address = address
    billing_address.delete(:state)
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(billing_address:))
  end

  def test_ip_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(ip: '192.18.123.12'))
  end

  def test_void
    assert_success response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success void = @gateway.void(response.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', void.message
    assert void.params['cancel_received_order_code']
  end

  def test_void_with_elo
    assert_success response = @gateway.authorize(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success void = @gateway.void(response.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', void.message
    assert void.params['cancel_received_order_code']
  end

  def test_void_nonexistent_transaction
    assert_failure response = @gateway.void('non_existent_authorization')
    assert_equal 'Could not find payment for order', response.message
  end

  def test_authorize_fractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(currency: 'USD')))
    assert_equal 'USD', result.params['amount_currency_code']
    assert_equal '1234', result.params['amount_value']
    assert_equal '2', result.params['amount_exponent']
  end

  def test_authorize_nonfractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(currency: 'IDR')))
    assert_equal 'IDR', result.params['amount_currency_code']
    assert_equal '12', result.params['amount_value']
    assert_equal '0', result.params['amount_exponent']
  end

  def test_authorize_three_decimal_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(currency: 'OMR')))
    assert_equal 'OMR', result.params['amount_currency_code']
    assert_equal '1234', result.params['amount_value']
    assert_equal '3', result.params['amount_exponent']
  end

  def test_reference_transaction
    assert_success(original = @gateway.authorize(100, @credit_card, @options))
    assert_success(@gateway.authorize(200, original.authorization, order_id: generate_unique_id))
  end

  def test_invalid_login
    gateway = WorldpayGateway.new(login: '', password: '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  def test_refund_fails_unless_status_is_captured
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success(response)

    assert refund = @gateway.refund(30, response.authorization)
    assert_failure refund
    assert_equal 'Order not ready', refund.message
  end

  def test_refund_nonexistent_transaction
    assert_failure response = @gateway.refund(@amount, 'non_existent_authorization')
    assert_equal 'Could not find payment for order', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_verify_with_0_auth
    options = @options.merge(zero_dollar_auth: true)
    response = @gateway.verify(@credit_card, options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_verify_with_0_auth_and_ineligible_card
    options = @options.merge(zero_dollar_auth: true)
    response = @gateway.verify(@amex_card, options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_verify_with_elo
    response = @gateway.verify(@elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REFUSED}, response.message
  end

  def test_successful_visa_credit_on_cft_gateway
    credit = @cftgateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_successful_mastercard_credit_on_cft_gateway
    cc = credit_card('5555555555554444')
    credit = @cftgateway.credit(@amount, cc, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_successful_visa_account_funding_transfer
    credit = @gateway.credit(@amount, @credit_card, @options.merge(@aft_options))
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_successful_visa_account_funding_transfer_via_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    credit = @gateway.credit(@amount, store.authorization, @options.merge(@aft_options))
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_failed_visa_account_funding_transfer
    credit = @gateway.credit(@amount, credit_card('4111111111111111', name: 'REFUSED'), @options.merge(@aft_options))
    assert_failure credit
    assert_equal 'REFUSED', credit.message
  end

  def test_failed_visa_account_funding_transfer_acquirer_error
    credit = @gateway.credit(@amount, credit_card('4111111111111111', name: 'ACQERROR'), @options.merge(@aft_options))
    assert_failure credit
    assert_equal 'ACQUIRER ERROR', credit.message
    assert_equal '20', credit.error_code
  end

  def test_successful_authorize_visa_account_funding_transfer
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(@aft_options))
    assert_success auth
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal 'SUCCESS', auth.message
  end

  def test_successful_authorize_visa_account_funding_transfer_via_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    auth = @gateway.authorize(@amount, store.authorization, @options.merge(@aft_options))
    assert_success auth
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal 'SUCCESS', auth.message
  end

  def test_successful_authorize_visa_account_funding_transfer_3ds
    options = @options.merge(@aft_options, { execute_threed: true, three_ds_version: '2.0' })
    assert auth = @gateway.authorize(@amount, @threeDS2_card, options)
    assert_success auth
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal 'SUCCESS', auth.message
  end

  def test_failed_authorize_visa_account_funding_transfer
    auth = @gateway.authorize(@amount, credit_card('4111111111111111', name: 'REFUSED'), @options.merge(@aft_options))
    assert_failure auth
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal 'REFUSED', auth.message
  end

  def test_failed_authorize_visa_account_funding_transfer_acquirer_error
    auth = @gateway.authorize(@amount, credit_card('4111111111111111', name: 'ACQERROR'), @options.merge(@aft_options))
    assert_failure auth
    assert_equal 'ACQUIRER ERROR', auth.message
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal '20', auth.error_code
  end

  def test_successful_authorize_visa_account_funding_transfer_with_no_middle_name_address2
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(@aft_less_options))
    assert_success auth
    assert_equal 'funding_transfer_transaction', auth.params['action']
    assert_equal 'SUCCESS', auth.message
  end

  def test_successful_fast_fund_credit_on_cft_gateway
    options = @options.merge({ fast_fund_credit: true })

    credit = @cftgateway.credit(@amount, @credit_card, options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_successful_fast_fund_credit_with_token_on_cft_gateway
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    options = @options.merge({ fast_fund_credit: true })
    assert credit = @cftgateway.credit(@amount, store.authorization, options)
    assert_success credit
  end

  def test_failed_fast_fund_credit_on_cft_gateway
    options = @options.merge({ fast_fund_credit: true })
    refused_card = credit_card('4444333322221111', name: 'REFUSED') # 'magic' value for testing failures, provided by Worldpay

    credit = @cftgateway.credit(@amount, refused_card, options)
    assert_failure credit
    assert_equal '01', credit.params['action_code']
    assert_equal "A transaction status of 'ok' or 'PUSH_APPROVED' is required.", credit.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_failed_authorize_with_unknown_card
    assert auth = @gateway.authorize(@amount, @sodexo_voucher, @options)
    assert_failure auth
    assert_equal '5', auth.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, auth.message
  end

  def test_failed_purchase_with_unknown_card
    assert response = @gateway.purchase(@amount, @sodexo_voucher, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  def test_failed_verify_with_unknown_card
    response = @gateway.verify(@sodexo_voucher, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  # Worldpay has a delay between asking for a transaction to be captured and actually marking it as captured
  # These 2 tests work if you get authorizations from a purchase, wait some time and then perform the refund/void operation.
  #
  # def test_get_authorization
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert response.authorization
  #   puts 'auth: ' + response.authorization
  # end
  #
  def test_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.refund(@amount, response.authorization, authorization_validated: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_cancel_or_refund_non_captured_purchase
    response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_capture: true))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.refund(@amount, response.authorization, authorization_validated: true, cancel_or_refund: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_cancel_or_refund_captured_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.refund(@amount, response.authorization, authorization_validated: true, cancel_or_refund: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_cancel_or_refund_non_captured_purchase_with_void
    response = @gateway.purchase(@amount, @credit_card, @options.merge(skip_capture: true))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.void(response.authorization, authorization_validated: true, cancel_or_refund: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_cancel_or_refund_captured_purchase_with_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.void(response.authorization, authorization_validated: true, cancel_or_refund: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_multiple_refunds
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'SUCCESS', purchase.message

    partial_amount = @amount - 1
    assert_success refund1 = @gateway.refund(partial_amount, purchase.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', refund1.message

    assert_success refund2 = @gateway.refund(@amount - partial_amount, purchase.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', refund2.message
  end

  # def test_void_fails_unless_status_is_authorised
  #   response = @gateway.void('replace_with_authorization') # existing transaction in CAPTURED state
  #   assert_failure response
  #   assert_equal 'A transaction status of 'AUTHORISED' is required.', response.message
  # end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @store_options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match response.params['payment_token_id'], response.authorization
    assert_match 'shopper', response.authorization
    assert_match @store_options[:customer], response.authorization
  end

  def test_successful_store_with_transaction_identifier_using_gateway_specific_field
    transaction_identifier = 'ABC123'
    options_with_transaction_id = @store_options.merge(stored_credential_transaction_id: transaction_identifier)
    assert response = @gateway.store(@credit_card, options_with_transaction_id)

    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match transaction_identifier, response.params['transaction_identifier']
  end

  def test_successful_store_with_transaction_identifier_using_normalized_fields
    transaction_identifier = 'CDE456'
    options_with_transaction_id = @store_options.merge(stored_credential: { network_transaction_id: transaction_identifier })
    assert response = @gateway.store(@credit_card, options_with_transaction_id)

    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match transaction_identifier, response.params['transaction_identifier']
  end

  def test_successful_purchase_with_statement_narrative
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(statement_narrative: 'Merchant Statement Narrative'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_using_token_and_minimum_options
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, order_id: generate_unique_id)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_verify_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    response = @gateway.verify(store.authorization, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_credit_using_token
    assert store = @cftgateway.store(@credit_card, @store_options)
    assert_success store

    credit = @cftgateway.credit(@amount, store.authorization, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_failed_store
    assert response = @gateway.store(@credit_card, @store_options.merge(customer: '_invalidId'))
    assert_failure response
    assert_equal '2', response.error_code
    assert_equal 'authenticatedShopperID cannot start with an underscore', response.message
  end

  def test_failed_authorize_using_token
    assert store = @gateway.store(@declined_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_equal 'REFUSED', response.message
  end

  def test_failed_authorize_using_bogus_token
    assert response = @gateway.authorize(@amount, '|this|is|bogus', @options)
    assert_failure response
    assert_equal '2', response.error_code
    assert_match 'tokenScope', response.message
  end

  def test_failed_verify_using_token
    assert store = @gateway.store(@declined_card, @store_options)
    assert_success store

    response = @gateway.verify(store.authorization, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{REFUSED}, response.message
  end

  def test_authorize_and_capture_synchronous_response
    card = credit_card('4111111111111111', verification_value: 555)
    assert auth = @cftgateway.authorize(@amount, card, @options)
    assert_success auth

    assert capture = @cftgateway.capture(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_success capture

    assert duplicate_capture = @cftgateway.capture(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_failure duplicate_capture
  end

  def test_capture_wrong_amount_synchronous_response
    card = credit_card('4111111111111111', verification_value: 555)
    assert auth = @cftgateway.authorize(@amount, card, @options)
    assert_success auth

    assert capture = @cftgateway.capture(@amount + 1, auth.authorization, @options.merge(authorization_validated: true))
    assert_failure capture
    assert_equal '5', capture.error_code
    assert_equal 'Requested capture amount (GBP 1.01) exceeds the authorised balance for this payment (GBP 1.00)', capture.message
  end

  def test_successful_refund_synchronous_response
    response = @cftgateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    assert @cftgateway.refund(@amount, response.authorization, authorization_validated: true)
  end

  def test_failed_refund_synchronous_response
    auth = @cftgateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization

    refund = @cftgateway.refund(@amount, auth.authorization, authorization_validated: true)
    assert_failure refund
    assert_equal 'This order is not refundable', refund.message

    assert capture = @cftgateway.capture(@amount, auth.authorization, @options.merge(authorization_validated: true))
    assert_success capture

    refund = @cftgateway.refund(@amount * 2, auth.authorization, authorization_validated: true)
    assert_failure refund
    assert_equal 'Invalid amount: The refund amount should be equal to the captured value', refund.message
  end

  def test_successful_purchase_with_options_synchronous_response
    options = @options
    stored_credential_params = stored_credential(:initial, :unscheduled, :merchant)
    options.merge(stored_credential: stored_credential_params)

    assert purchase = @cftgateway.purchase(@amount, @credit_card, options.merge(instalments: 3, skip_capture: true, authorization_validated: true))
    assert_success purchase
  end

  # There is a delay of up to 5 minutes for a transaction to be recorded by Worldpay. Inquiring
  # too soon will result in an error "Order not ready". Leaving commented out due to included sleeps.
  # def test_successful_inquire_with_order_id
  #   order_id = @options[:order_id]
  #   assert auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #   assert auth.authorization
  #   sleep 60

  #   assert inquire = @gateway.inquire(nil, { order_id: order_id })
  #   assert_success inquire
  #   assert auth.authorization == inquire.authorization
  # end

  # def test_successful_inquire_with_authorization
  #   assert auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth
  #   assert auth.authorization
  #   sleep 60

  #   assert inquire = @gateway.inquire(auth.authorization, {})
  #   assert_success inquire
  #   assert auth.authorization == inquire.authorization
  # end

  private

  def risk_data
    return @risk_data if @risk_data

    authentication_time = Time.now
    shopper_account_creation_date = Date.today
    shopper_account_modification_date = Date.today - 1.day
    shopper_account_password_change_date = Date.today - 2.days
    shopper_account_shipping_address_first_use_date = Date.today - 3.day
    shopper_account_payment_account_first_use_date = Date.today - 4.day
    transaction_risk_data_pre_order_date = Date.today + 1.day

    @risk_data = {
      authentication_risk_data: {
        authentication_method: 'localAccount',
        authentication_date: {
          day_of_month: authentication_time.strftime('%d'),
          month: authentication_time.strftime('%m'),
          year: authentication_time.strftime('%Y'),
          hour: authentication_time.strftime('%H'),
          minute: authentication_time.strftime('%M'),
          second: authentication_time.strftime('%S')
        }
      },
      shopper_account_risk_data: {
        transactions_attempted_last_day: '1',
        transactions_attempted_last_year: '2',
        purchases_completed_last_six_months: '3',
        add_card_attempts_last_day: '4',
        previous_suspicious_activity: 'false', # Boolean (true or false)
        shipping_name_matches_account_name: 'true', #	Boolean (true or false)
        shopper_account_age_indicator: 'lessThanThirtyDays', # Possible Values: noAccount, createdDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_change_indicator: 'thirtyToSixtyDays', # Possible values: changedDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_password_change_indicator: 'noChange', # Possible Values: noChange, changedDuringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_shipping_address_usage_indicator: 'moreThanSixtyDays', # Possible Values: thisTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_payment_account_indicator: 'thirtyToSixtyDays', # Possible Values: noAccount, duringTransaction, lessThanThirtyDays, thirtyToSixtyDays, moreThanSixtyDays
        shopper_account_creation_date: {
          day_of_month: shopper_account_creation_date.strftime('%d'),
          month: shopper_account_creation_date.strftime('%m'),
          year: shopper_account_creation_date.strftime('%Y')
        },
        shopper_account_modification_date: {
          day_of_month: shopper_account_modification_date.strftime('%d'),
          month: shopper_account_modification_date.strftime('%m'),
          year: shopper_account_modification_date.strftime('%Y')
        },
        shopper_account_password_change_date: {
          day_of_month: shopper_account_password_change_date.strftime('%d'),
          month: shopper_account_password_change_date.strftime('%m'),
          year: shopper_account_password_change_date.strftime('%Y')
        },
        shopper_account_shipping_address_first_use_date: {
          day_of_month: shopper_account_shipping_address_first_use_date.strftime('%d'),
          month: shopper_account_shipping_address_first_use_date.strftime('%m'),
          year: shopper_account_shipping_address_first_use_date.strftime('%Y')
        },
        shopper_account_payment_account_first_use_date: {
          day_of_month: shopper_account_payment_account_first_use_date.strftime('%d'),
          month: shopper_account_payment_account_first_use_date.strftime('%m'),
          year: shopper_account_payment_account_first_use_date.strftime('%Y')
        }
      },
      transaction_risk_data: {
        shipping_method: 'digital',
        delivery_timeframe: 'electronicDelivery',
        delivery_email_address: 'abe@lincoln.gov',
        reordering_previous_purchases: 'false',
        pre_order_purchase: 'false',
        gift_card_count: '0',
        transaction_risk_data_gift_card_amount: {
          value: '123',
          currency: 'EUR',
          exponent: '2',
          debit_credit_indicator: 'credit'
        },
        transaction_risk_data_pre_order_date: {
          day_of_month: transaction_risk_data_pre_order_date.strftime('%d'),
          month: transaction_risk_data_pre_order_date.strftime('%m'),
          year: transaction_risk_data_pre_order_date.strftime('%Y')
        }
      }
    }
  end
end
