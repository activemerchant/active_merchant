require 'timecop'
require 'test_helper'

class RemoteCheckoutV2Test < Test::Unit::TestCase
  def setup
    gateway_fixtures = fixtures(:checkout_v2)
    gateway_token_fixtures = fixtures(:checkout_v2_token)
    @gateway = CheckoutV2Gateway.new(secret_key: gateway_fixtures[:secret_key])
    @gateway_oauth = CheckoutV2Gateway.new({ client_id: gateway_fixtures[:client_id], client_secret: gateway_fixtures[:client_secret] })
    @gateway_token = CheckoutV2Gateway.new(secret_key: gateway_token_fixtures[:secret_key], public_key: gateway_token_fixtures[:public_key])

    @amount = 200
    @credit_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: Time.now.year + 1)
    @credit_card_dnh = credit_card('4024007181869214', verification_value: '100', month: '6', year: Time.now.year + 1)
    @expired_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: '2010')
    @declined_card = credit_card('42424242424242424', verification_value: '234', month: '6', year: Time.now.year + 1)
    @threeds_card = credit_card('4485040371536584', verification_value: '100', month: '12', year: Time.now.year + 1)
    @mada_card = credit_card('5043000000000000', brand: 'mada')

    @vts_network_token = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :network_token,
      brand: 'visa',
      verification_value: nil
    )

    @mdes_network_token = network_tokenization_credit_card(
      '5436031030606378',
      eci: '02',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :network_token,
      brand: 'master',
      verification_value: nil
    )

    @google_pay_visa_cryptogram_3ds_network_token = network_tokenization_credit_card(
      '4242424242424242',
      eci: '05',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: nil
    )

    @google_pay_master_cryptogram_3ds_network_token = network_tokenization_credit_card(
      '5436031030606378',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :google_pay,
      brand: 'master',
      verification_value: nil
    )

    @google_pay_pan_only_network_token = network_tokenization_credit_card(
      '4242424242424242',
      month: '10',
      year: Time.now.year + 1,
      source:  :google_pay,
      verification_value: nil
    )

    @apple_pay_network_token = network_tokenization_credit_card(
      '4242424242424242',
      eci: '05',
      payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
      month: '10',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: nil
    )

    @options = {
      order_id: '1',
      billing_address: address,
      shipping_address: address,
      description: 'Purchase',
      email: 'longbob.longsen@example.com',
      processing_channel_id: 'pc_lxgl7aqahkzubkundd2l546hdm'
    }
    @options_for_verify = @options.merge({
      amount_allocations: [
        {
          id: 'ent_123',
          amount: 0
        }
      ]
    })
    @additional_options = @options.merge(
      card_on_file: true,
      transaction_indicator: 2,
      previous_charge_id: 'pay_123',
      processing_channel_id: 'pc_123'
    )
    @additional_options_3ds = @options.merge(
      execute_threed: true,
      three_d_secure: {
        version: '1.0.2',
        eci: '06',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        xid: 'MDAwMDAwMDAwMDAwMDAwMzIyNzY=',
        authentication_response_status: 'Y'
      }
    )
    @additional_options_3ds2 = @options.merge(
      execute_threed: true,
      attempt_n3d: true,
      challenge_indicator: 'no_preference',
      exemption: 'trusted_listing',
      three_d_secure: {
        version: '2.0.0',
        eci: '06',
        cavv: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA',
        ds_transaction_id: 'MDAwMDAwMDAwMDAwMDAwMzIyNzY=',
        authentication_response_status: 'Y'
      }
    )
    @additional_options_risk = @options.merge(
      risk: {
        enabled: true,
        device_session_id: 'dsid_ipsmclhxwq72phhr32iwfvrflm'
      }
    )
    @extra_customer_data = @options.merge(
      phone_country_code: '1',
      phone: '9108675309'
    )
    @payout_options = @options.merge(
      source_type: 'currency_account',
      source_id: 'ca_spwmped4qmqenai7hcghquqle4',
      funds_transfer_type: 'FD',
      instruction_purpose: 'leisure',
      destination: {
        account_holder: {
          phone: {
            number: '9108675309',
            country_code: '1'
          },
          identification: {
            type: 'passport',
            number: '12345788848438'
          }
        }
      },
      currency: 'GBP',
      sender: {
        type: 'individual',
        first_name: 'Jane',
        middle_name: 'Middle',
        last_name: 'Doe',
        address: {
          address1: '123 Main St',
          address2: 'Apt G',
          city: 'Narnia',
          state: 'ME',
          zip: '12345',
          country: 'US'
        },
        reference: '012345',
        reference_type: 'other',
        source_of_funds: 'debit',
        identification: {
          type: 'passport',
          number: 'ABC123',
          issuing_country: 'US',
          date_of_expiry: '2027-07-07'
        }
      }
    )
  end

  def test_failed_access_token
    assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = CheckoutV2Gateway.new({ client_id: 'YOUR_CLIENT_ID', client_secret: 'YOUR_CLIENT_SECRET' })
      gateway.send :setup_access_token
    end
  end

  def test_failed_purchase_with_failed_oauth_credentials
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = CheckoutV2Gateway.new({ client_id: 'YOUR_CLIENT_ID', client_secret: 'YOUR_CLIENT_SECRET' })
      gateway.purchase(@amount, @credit_card, @options)
    end

    assert_equal error.message, 'Failed with 400 Bad Request'
  end

  def test_transcript_scrubbing
    declined_card = credit_card('4000300011112220', verification_value: '423')
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, declined_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(declined_card.number, transcript)
    assert_scrubbed(declined_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

  def test_transcript_scrubbing_via_oauth
    declined_card = credit_card('4000300011112220', verification_value: '309')
    transcript = capture_transcript(@gateway_oauth) do
      @gateway_oauth.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway_oauth.scrub(transcript)
    assert_scrubbed(declined_card.number, transcript)
    assert_scrubbed(declined_card.verification_value, transcript)
    assert_scrubbed(@gateway_oauth.options[:client_id], transcript)
    assert_scrubbed(@gateway_oauth.options[:client_secret], transcript)
    assert_scrubbed(@gateway_oauth.options[:access_token], transcript)
  end

  def test_network_transaction_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(100, @apple_pay_network_token, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@apple_pay_network_token.payment_cryptogram, transcript)
    assert_scrubbed(@apple_pay_network_token.number, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

  def test_store_transcript_scrubbing
    response = nil
    transcript = capture_transcript(@gateway) do
      response = @gateway_token.store(@credit_card, @options)
    end
    token = response.responses.first.params['token']
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(token, transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_via_oauth
    response = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_via_oauth_with_access_token
    assert_nil @gateway_oauth.options[:access_token]
    assert_nil @gateway_oauth.options[:expires]
    purchase = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success purchase
    access_token = @gateway_oauth.options[:access_token]
    expires = @gateway_oauth.options[:expires]
    response = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal @gateway_oauth.options[:access_token], access_token
    assert_equal @gateway_oauth.options[:expires], expires
  end

  def test_failure_purchase_via_oauth_with_invalid_access_token_without_expires
    @gateway_oauth.options[:access_token] = 'ABC123'
    @gateway_oauth.options[:expires] = DateTime.now.strftime('%Q').to_i + 3600.seconds

    response = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '401: Unauthorized', response.message
    assert_equal @gateway_oauth.options[:access_token], ''
  end

  def test_successful_purchase_via_oauth_with_invalid_access_token_with_correct_expires
    @gateway_oauth.options[:access_token] = 'ABC123'
    response = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_equal 'ABC123', @gateway_oauth.options[:access_token]
  end

  def test_successful_purchase_with_an_expired_access_token
    initial_access_token = @gateway_oauth.options[:access_token] = SecureRandom.alphanumeric(10)
    initial_expires = @gateway_oauth.options[:expires] = DateTime.now.strftime('%Q').to_i

    Timecop.freeze(DateTime.now + 1.hour) do
      purchase = @gateway_oauth.purchase(@amount, @credit_card, @options)
      assert_success purchase

      assert_equal 2, purchase.responses.size
      assert_not_equal initial_access_token, @gateway_oauth.options[:access_token]
      assert_not_equal initial_expires, @gateway.options[:expires]

      assert_not_nil purchase.responses.first.params['access_token']
      assert_not_nil purchase.responses.first.params['expires']
    end
  end

  def test_successful_purchase_with_vts_network_token
    response = @gateway.purchase(100, @vts_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_not_nil response.params['source']['payment_account_reference']
  end

  def test_successful_purchase_with_vts_network_token_via_oauth
    response = @gateway_oauth.purchase(100, @vts_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_not_nil response.params['source']['payment_account_reference']
  end

  def test_successful_purchase_with_mdes_network_token
    response = @gateway.purchase(100, @mdes_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_not_nil response.params['source']['payment_account_reference']
  end

  def test_successful_purchase_with_google_pay_visa_cryptogram_3ds_network_token
    response = @gateway.purchase(100, @google_pay_visa_cryptogram_3ds_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_google_pay_visa_cryptogram_3ds_network_token_via_oauth
    response = @gateway_oauth.purchase(100, @google_pay_visa_cryptogram_3ds_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_google_pay_master_cryptogram_3ds_network_token
    response = @gateway.purchase(100, @google_pay_master_cryptogram_3ds_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_google_pay_pan_only_network_token
    response = @gateway.purchase(100, @google_pay_pan_only_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_apple_pay_network_token
    response = @gateway.purchase(100, @apple_pay_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_apple_pay_network_token_via_oauth
    response = @gateway_oauth.purchase(100, @apple_pay_network_token, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  # # currently, checkout does not provide any valid test card numbers for testing mada cards
  # def test_successful_purchase_with_mada_card
  #   response = @gateway.purchase(@amount, @mada_card, @options)
  #   assert_success response
  #   assert_equal 'Succeeded', response.message
  # end

  def test_successful_purchase_with_additional_options
    response = @gateway.purchase(@amount, @credit_card, @additional_options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_stored_credentials
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_response = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success initial_response
    assert_equal 'Succeeded', initial_response.message
    assert_not_nil initial_response.params['id']
    network_transaction_id = initial_response.params['id']

    stored_options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'installment',
        network_transaction_id: network_transaction_id
      }
    )
    response = @gateway.purchase(@amount, @credit_card, stored_options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_stored_credentials_via_oauth
    initial_options = @options.merge(
      stored_credential: {
        initial_transaction: true,
        reason_type: 'recurring'
      }
    )
    initial_response = @gateway_oauth.purchase(@amount, @credit_card, initial_options)
    assert_success initial_response
    assert_equal 'Succeeded', initial_response.message
    assert_not_nil initial_response.params['id']
    network_transaction_id = initial_response.params['id']

    stored_options = @options.merge(
      stored_credential: {
        initial_transaction: false,
        reason_type: 'installment',
        network_transaction_id: network_transaction_id
      }
    )
    response = @gateway_oauth.purchase(@amount, @credit_card, stored_options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_stored_credentials_merchant_initiated_transaction_id
    stored_options = @options.merge(
      stored_credential: {
        reason_type: 'installment'
      },
      merchant_initiated_transaction_id: 'pay_7emayabnrtjkhkrbohn4m2zyoa321'
    )
    response = @gateway.purchase(@amount, @credit_card, stored_options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_moto_flag
    response = @gateway.authorize(@amount, @credit_card, @options.merge(transaction_indicator: 3))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_moto_flag_via_oauth
    response = @gateway_oauth.authorize(@amount, @credit_card, @options.merge(transaction_indicator: 3))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_manual_entry_flag
    response = @gateway.authorize(@amount, @credit_card, @options.merge(metadata: { manual_entry: true }))

    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_includes_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
  end

  def test_successful_purchase_includes_avs_result_via_oauth
    response = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'G', response.avs_result['code']
    assert_equal 'Non-U.S. issuing bank does not support AVS.', response.avs_result['message']
  end

  def test_successful_authorize_includes_avs_result
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
  end

  def test_successful_purchase_includes_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_purchase_with_extra_customer_data
    response = @gateway.purchase(@amount, @credit_card, @extra_customer_data)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_includes_cvv_result
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_authorize_includes_cvv_result_via_oauth
    response = @gateway_oauth.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_authorize_with_estimated_type
    response = @gateway.authorize(@amount, @credit_card, @options.merge({ authorization_type: 'Estimated' }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_with_incremental_authoriation
    response = @gateway_oauth.authorize(@amount, @credit_card, @options.merge({ authorization_type: 'Estimated' }))
    assert_success response
    assert_equal 'Succeeded', response.message

    response = @gateway_oauth.authorize(@amount, @credit_card, @options.merge({ incremental_authorization: response.authorization }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_with_estimated_type_via_oauth
    response = @gateway_oauth.authorize(@amount, @credit_card, @options.merge({ authorization_type: 'Estimated' }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_with_processing_channel_id
    response = @gateway.authorize(@amount, @credit_card, @options.merge({ processing_channel_id: 'pc_ovo75iz4hdyudnx6tu74mum3fq' }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_descriptors
    options = @options.merge(descriptor_name: 'shop', descriptor_city: 'london')
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_descriptors_via_oauth
    options = @options.merge(descriptor_name: 'shop', descriptor_city: 'london')
    response = @gateway_oauth.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_metadata
    options = @options.merge(
      metadata: {
        coupon_code: 'NY2018',
        partner_id: '123989'
      }
    )
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_processing_data
    options = @options.merge(
      processing: {
        aft: true,
        preferred_scheme: 'cartes_bancaires',
        app_id: 'com.iap.linker_portal',
        airline_data: [
          {
            ticket: {
              number: '045-21351455613',
              issue_date: '2023-05-20',
              issuing_carrier_code: 'AI',
              travel_package_indicator: 'B',
              travel_agency_name: 'World Tours',
              travel_agency_code: '01'
            },
            passenger: [
              {
                first_name: 'John',
                last_name: 'White',
                date_of_birth: '1990-05-26',
                address: {
                  country: 'US'
                }
              }
            ],
            flight_leg_details: [
              {
                flight_number: '101',
                carrier_code: 'BA',
                class_of_travelling: 'J',
                departure_airport: 'LHR',
                departure_date: '2023-06-19',
                departure_time: '15:30',
                arrival_airport: 'LAX',
                stop_over_code: 'x',
                fare_basis_code: 'SPRSVR'
              }
            ]
          }
        ],
        partner_customer_id: '2102209000001106125F8',
        partner_payment_id: '440644309099499894406',
        tax_amount: '1000',
        purchase_country: 'GB',
        locale: 'en-US',
        retrieval_reference_number: '909913440644',
        partner_order_id: 'string',
        partner_status: 'string',
        partner_transaction_id: 'string',
        partner_error_codes: [],
        partner_error_message: 'string',
        partner_authorization_code: 'string',
        partner_authorization_response_code: 'string',
        fraud_status: 'string'
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_recipient_data
    options = @options.merge(
      recipient: {
        dob: '1985-05-15',
        account_number: '5555554444',
        zip: 'SW1A',
        first_name: 'john',
        last_name: 'johnny',
        address: {
          address1: '123 High St.',
          address2: 'Flat 456',
          city: 'London',
          state: 'str',
          zip: 'SW1A 1AA',
          country: 'GB'
        }
      }
    )
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_sender_data
    options = @options.merge(
      sender: {
        type: 'individual',
        dob: '1985-05-15',
        first_name: 'Jane',
        last_name: 'Doe',
        address: {
          address_line1: '123 High St.',
          address_line2: 'Flat 456',
          city: 'London',
          state: 'str',
          zip: 'SW1A 1AA',
          country: 'GB'
        },
        reference: '8285282045818',
        identification: {
          type: 'passport',
          number: 'ABC123',
          issuing_country: 'GB'
        }
      }
    )
    response = @gateway_oauth.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_metadata_via_oauth
    options = @options.merge(
      metadata: {
        coupon_code: 'NY2018',
        partner_id: '123989'
      }
    )
    response = @gateway_oauth.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, billing_address: address)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_shipping_address
    response = @gateway.purchase(@amount, @credit_card, shipping_address: address)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_without_phone_number
    response = @gateway.purchase(@amount, @credit_card, billing_address: address.update(phone: nil))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_without_name
    credit_card = credit_card('4242424242424242', verification_value: '100', month: '6', year: Time.now.year + 1, first_name: nil, last_name: nil)
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_equal response.params['source']['name'], ''
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_ip
    response = @gateway.purchase(@amount, @credit_card, ip: '96.125.185.52')
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_risk_object
    response = gateway_oauth.purchase(@amount, @apple_pay_network_token, @additional_options_risk)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(100, @credit_card_dnh, @options)
    assert_failure response
    assert_equal 'Invalid Card Number', response.message
  end

  def test_failed_purchase_via_oauth
    response = @gateway_oauth.purchase(100, @declined_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_avs_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, billing_address: address.update(address1: 'Test_A'))
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_avs_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, billing_address: address.update(address1: 'Test_A'))
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_invalid_shipping_address
    response = @gateway.authorize(@amount, @credit_card, shipping_address: address.update(country: 'Canada'))
    assert_failure response
    assert_equal 'request_invalid: country_address_invalid', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_via_oauth
    auth = @gateway_oauth.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway_oauth.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture((@amount / 2).to_i, auth.authorization, { capture_type: 'NonFinal' })
    assert_success capture
  end

  def test_successful_authorize_and_partial_capture_via_oauth
    auth = @gateway_oauth.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway_oauth.capture((@amount / 2).to_i, auth.authorization, { capture_type: 'NonFinal' })
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_additional_options
    auth = @gateway.authorize(@amount, @credit_card, @additional_options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds
    auth = @gateway.authorize(@amount, @credit_card, @additional_options_3ds)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds_via_oauth
    auth = @gateway_oauth.authorize(@amount, @credit_card, @additional_options_3ds)
    assert_success auth

    assert capture = @gateway_oauth.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds2
    auth = @gateway.authorize(@amount, @credit_card, @additional_options_3ds2)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds2_via_oauth
    auth = @gateway_oauth.authorize(@amount, @credit_card, @additional_options_3ds2)
    assert_success auth

    assert capture = @gateway_oauth.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_successful_authorize_and_capture_with_metadata
    options = @options.merge(
      metadata: {
        coupon_code: 'NY2018',
        partner_id: '123989'
      }
    )

    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_direct_3ds_authorize
    auth = @gateway.authorize(@amount, @threeds_card, @options.merge(execute_threed: true))

    assert_equal 'Pending', auth.message
    assert_equal 'Y', auth.params['3ds']['enrolled']
    assert auth.params['_links']['redirect']
  end

  def test_failed_authorize
    response = @gateway.authorize(12314, @declined_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_failed_authorize_via_oauth
    response = @gateway_oauth.authorize(12314, @declined_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_number_invalid', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_failed_capture_via_oauth
    response = @gateway_oauth.capture(nil, '')
    assert_failure response
  end

  def test_successful_credit
    @credit_card.first_name = 'John'
    @credit_card.last_name = 'Doe'
    response = @gateway_oauth.credit(@amount, @credit_card, @options.merge({ source_type: 'currency_account', source_id: 'ca_spwmped4qmqenai7hcghquqle4', account_holder_type: 'individual' }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_money_transfer_payout_via_credit_individual_account_holder_type
    @credit_card.first_name = 'John'
    @credit_card.last_name = 'Doe'
    response = @gateway_oauth.credit(@amount, @credit_card, @payout_options.merge(account_holder_type: 'individual', payout: true))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_money_transfer_payout_via_credit_corporate_account_holder_type
    @credit_card.name = 'ACME, Inc.'
    response = @gateway_oauth.credit(@amount, @credit_card, @payout_options.merge(account_holder_type: 'corporate', payout: true))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_money_transfer_payout_reverts_to_credit_if_payout_sent_as_nil
    @credit_card.first_name = 'John'
    @credit_card.last_name = 'Doe'
    response = @gateway_oauth.credit(@amount, @credit_card, @payout_options.merge({ account_holder_type: 'individual', payout: nil }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_money_transfer_payout_handles_blank_destination_address
    @payout_options[:billing_address] = nil
    response = @gateway_oauth.credit(@amount, @credit_card, @payout_options.merge({ account_holder_type: 'individual', payout: true }))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_store
    response = @gateway_token.store(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_unstore_after_store
    store = @gateway_token.store(@credit_card, @options)
    assert_success store
    assert_equal 'Succeeded', store.message
    source_id = store.params['id']
    response = @gateway_token.unstore(source_id, @options)
    assert_success response
    assert_equal response.params['response_code'], '204'
  end

  def test_successful_unstore_after_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    source_id = purchase.params['source']['id']
    response = @gateway.unstore(source_id, @options)
    assert_success response
    assert_equal response.params['response_code'], '204'
  end

  def test_successful_purchase_after_purchase_with_google_pay
    purchase = @gateway.purchase(@amount, @google_pay_master_cryptogram_3ds_network_token, @options)
    source_id = purchase.params['source']['id']
    response = @gateway.purchase(@amount, source_id, @options.merge(source_id: source_id, source_type: 'id'))
    assert_success response
  end

  def test_successful_store_apple_pay
    response = @gateway.store(@apple_pay_network_token, @options)
    assert_success response
  end

  def test_successful_unstore_after_purchase_with_google_pay
    purchase = @gateway.purchase(@amount, @google_pay_master_cryptogram_3ds_network_token, @options)
    source_id = purchase.params['source']['id']
    response = @gateway.unstore(source_id, @options)
    assert_success response
  end

  def test_success_store_with_google_pay_3ds
    response = @gateway.store(@google_pay_visa_cryptogram_3ds_network_token, @options)
    assert_success response
  end

  def test_failed_store_oauth_credit_card
    response = @gateway_oauth.store(@credit_card, @options)
    assert_failure response
    assert_equal '401: Unauthorized', response.message
  end

  def test_successful_purchase_oauth_after_store_credit_card
    store = @gateway_token.store(@credit_card, @options)
    assert_success store
    token = store.params['id']
    response = @gateway_oauth.purchase(@amount, token, @options)
    assert_success response
  end

  def test_successful_purchase_after_store_with_google_pay
    store = @gateway.store(@google_pay_visa_cryptogram_3ds_network_token, @options)
    assert_success store
    token = store.params['id']
    response = @gateway.purchase(@amount, token, @options)
    assert_success response
  end

  def test_successful_purchase_after_store_with_apple_pay
    store = @gateway.store(@apple_pay_network_token, @options)
    assert_success store
    token = store.params['id']
    response = @gateway.purchase(@amount, token, @options)
    assert_success response
  end

  def test_success_purchase_oauth_after_store_ouath_with_apple_pay
    store = @gateway_oauth.store(@apple_pay_network_token, @options)
    assert_success store
    token = store.params['id']
    response = @gateway_oauth.purchase(@amount, token, @options)
    assert_success response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 1

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_successful_refund_via_oauth
    purchase = @gateway_oauth.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 1

    assert refund = @gateway_oauth.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_successful_refund_with_metadata
    options = @options.merge(
      metadata: {
        coupon_code: 'NY2018',
        partner_id: '123989'
      }
    )

    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    sleep 1

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 1

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_failed_refund_via_oauth
    response = @gateway_oauth.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_purchase_store_after_verify
    verify = @gateway.verify(@apple_pay_network_token, @options)
    assert_success verify
    source_id = verify.params['source']['id']
    response = @gateway.purchase(@amount, source_id, @options.merge(source_id: source_id, source_type: 'id'))
    assert_success response
    assert_success verify
  end

  def test_successful_void_via_oauth
    auth = @gateway_oauth.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway_oauth.void(auth.authorization)
    assert_success void
  end

  def test_successful_void_with_metadata
    options = @options.merge(
      metadata: {
        coupon_code: 'NY2018',
        partner_id: '123989'
      }
    )

    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_failed_void_via_oauth
    response = @gateway_oauth.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options_for_verify)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_successful_verify_via_oauth
    response = @gateway_oauth.verify(@credit_card, @options_for_verify)
    assert_success response
    assert_match %r{Succeeded}, response.message
    assert_not_nil response.responses.first.params['access_token']
    assert_not_nil response.responses.first.params['expires']
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options_for_verify)
    assert_failure response
    assert_match %r{request_invalid: card_number_invalid}, response.message
  end

  def test_expired_card_returns_error_code
    response = @gateway.purchase(@amount, @expired_card, @options)
    assert_failure response
    assert_equal 'request_invalid: card_expired', response.message
    assert_equal 'request_invalid: card_expired', response.error_code
  end

  def test_successful_purchase_with_idempotency_key
    response = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: 'test123'))
    assert_success response
    assert_equal 'Succeeded', response.message
  end
end
