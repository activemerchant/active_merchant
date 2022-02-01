require 'test_helper'

class RemoteBlueSnapTest < Test::Unit::TestCase
  def setup
    @gateway = BlueSnapGateway.new(fixtures(:blue_snap))

    @amount = 100
    @credit_card = credit_card('4263982640269299')
    @cabal_card = credit_card('6271701225979642', month: 3, year: 2024)
    @naranja_card = credit_card('5895626746595650', month: 11, year: 2024)
    @declined_card = credit_card('4917484589897107', month: 1, year: 2023)
    @invalid_card = credit_card('4917484589897106', month: 1, year: 2023)
    @three_ds_visa_card = credit_card('4000000000001091', month: 1)
    @three_ds_master_card = credit_card('5200000000001096', month: 1)
    @invalid_cabal_card = credit_card('5896 5700 0000 0000', month: 1, year: 2023)

    # BlueSnap may require support contact to activate fraud checking on sandbox accounts.
    # Specific merchant-configurable thresholds can be set as follows:
    # Order Total Amount Decline Threshold = 3728
    # Payment Country Decline List = Brazil
    @fraudulent_amount = 3729
    @fraudulent_card = credit_card('4007702835532454')

    @options = { billing_address: address }
    @options_3ds2 = @options.merge(
      three_d_secure: {
        eci: '05',
        cavv: 'AAABAWFlmQAAAABjRWWZEEFgFz+A',
        xid: 'MGpHWm5ZWVpKclo0aUk0VmltVDA=',
        ds_transaction_id: 'jhg34-sdgds87-sdg87-sdfg7',
        version: '2.2.0'
      }
    )

    @check = check
    @invalid_check = check(routing_number: '123456', account_number: '123456789')
    @valid_check_options = {
      billing_address: {
        address1: '123 Street',
        address2: 'Apt 1',
        city: 'Happy City',
        state: 'CA',
        zip: '94901'
      },
      authorized_by_shopper: true
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_fractionless_currency_purchase
    options = @options.merge(currency: 'JPY')
    response = @gateway.purchase(12300, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_three_decimal_currency_purchase
    options = @options.merge(currency: 'BHD')
    response = @gateway.purchase(1234, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_cabal_card
    options = @options.merge({
      email: 'joe@example.com'
    })
    response = @gateway.purchase(@amount, @cabal_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_naranja_card
    options = @options.merge({
      email: 'joe@example.com'
    })
    response = @gateway.purchase(@amount, @naranja_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      description: 'Product Description',
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal 'Success', response.message

    # description SHOULD BE set as a meta-data field
    assert_not_empty response.params['transaction-meta-data']
    meta = response.params['transaction-meta-data']

    assert_equal 1, meta.length
    assert_equal 'description', meta[0]['meta-key']
    assert_equal 'Product Description', meta[0]['meta-value']
    assert_equal 'Description', meta[0]['meta-description']
  end

  def test_successful_purchase_with_meta_data
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      transaction_meta_data: [
        {
          meta_key: 'stateTaxAmount',
          meta_value: '20.00',
          meta_description: 'State Tax Amount'
        },
        {
          meta_key: 'cityTaxAmount',
          meta_value: '10.00',
          meta_description: 'City Tax Amount'
        },
        {
          meta_key: 'description',
          meta_value: 'Product ABC',
          meta_description: 'Product Description'
        }
      ],
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal 'Success', response.message

    # description SHOULD BE set as a meta-data field
    assert_not_empty response.params['transaction-meta-data']
    meta = response.params['transaction-meta-data']

    assert_equal 3, meta.length

    meta.each { |m|
      assert_true m['meta-key'].length > 0
      assert_true m['meta-value'].length > 0
      assert_true m['meta-description'].length > 0

      case m['meta-key']
      when 'description'
        assert_equal 'Product ABC', m['meta-value']
        assert_equal 'Product Description', m['meta-description']
      when 'cityTaxAmount'
        assert_equal '10.00', m['meta-value']
        assert_equal 'City Tax Amount', m['meta-description']
      when 'stateTaxAmount'
        assert_equal '20.00', m['meta-value']
        assert_equal 'State Tax Amount', m['meta-description']
      end
    }
  end

  def test_successful_purchase_with_metadata_empty
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ'
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal 'Success', response.message

    assert_nil response.params['transaction-meta-data']
  end

  def test_successful_purchase_with_card_holder_info
    more_options = @options.merge({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      soft_descriptor: 'OnCardStatement',
      personal_identification_number: 'CNPJ',
      billing_address: {
        address1: '123 Street',
        address2: 'Apt 1',
        city: 'Happy City',
        state: 'CA',
        zip: '94901'
      },
      phone_number: '555 888 0000'
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_shipping_contact_info
    more_options = @options.merge({
      shipping_address: {
        address1: '123 Main St',
        address2: 'Apt B',
        city: 'Springfield',
        state: 'NC',
        country: 'US',
        zip: '27701'
      }
    })

    response = @gateway.purchase(@amount, @credit_card, more_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_3ds2_auth
    response = @gateway.purchase(@amount, @three_ds_visa_card, @options_3ds2)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_currency
    response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'CAD'))
    assert_success response

    assert_equal 'Success', response.message
    assert_equal 'CAD', response.params['currency']
  end

  def test_successful_purchase_with_level3_data
    l_three_visa = credit_card('4111111111111111', month: 2, year: 2023)
    options = @options.merge({
      customer_reference_number: '1234A',
      sales_tax_amount: 0.6,
      freight_amount: 0,
      duty_amount: 0,
      destination_zip_code: 12345,
      destination_country_code: 'us',
      ship_from_zip_code: 12345,
      discount_amount: 0,
      tax_amount: 0.6,
      tax_rate: 6.0,
      level_3_data_items: [
        {
          line_item_total: 9.00,
          description: 'test_desc',
          product_code: 'test_code',
          item_quantity: 1.0,
          tax_rate: 6.0,
          tax_amount: 0.60,
          unit_of_measure: 'lb',
          commodity_code: 123,
          discount_indicator: 'Y',
          gross_net_indicator: 'Y',
          tax_type: 'test',
          unit_cost: 10.00
        },
        {
          line_item_total: 9.00,
          description: 'test_2',
          product_code: 'test_2',
          item_quantity: 1.0,
          tax_rate: 7.0,
          tax_amount: 0.70,
          unit_of_measure: 'lb',
          commodity_code: 123,
          discount_indicator: 'Y',
          gross_net_indicator: 'Y',
          tax_type: 'test',
          unit_cost: 14.00
        }
      ]
    })
    response = @gateway.purchase(@amount, l_three_visa, options)

    assert_success response
    assert_equal 'Success', response.message
    assert_equal '1234A', response.params['customer-reference-number']
    assert_equal '9', response.params['line-item-total']
  end

  def test_successful_purchase_with_unused_state_code
    unrecognized_state_code_options = {
      billing_address: {
        city: 'Dresden',
        state: 'Sachsen',
        country: 'DE',
        zip: '01069'
      }
    }

    response = @gateway.purchase(@amount, @credit_card, unrecognized_state_code_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_transaction_fraud_info
    fraud_info_options = @options.merge({
      ip: '123.12.134.1',
      transaction_fraud_info: {
        fraud_session_id: 'fbcc094208f54c0e974d56875c73af7a'
      }
    })

    response = @gateway.purchase(@amount, @credit_card, fraud_info_options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options.merge(@valid_check_options))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_fraudulent_purchase
    # Reflects specific settings on Bluesnap sandbox account.
    response = @gateway.purchase(@fraudulent_amount, @fraudulent_card, @options)
    assert_failure response
    assert_match(/fraud-reference-id/, response.message)
    assert_match(/fraud-event/, response.message)
    assert_match(/blacklistPaymentCountryDecline/, response.message)
    assert_match(/orderTotalDecline/, response.message)
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Authorization has failed for this transaction/, response.message)
    assert_equal '14002', response.error_code
  end

  def test_failed_purchase_with_invalid_cabal_card
    response = @gateway.purchase(@amount, @invalid_cabal_card, @options)
    assert_failure response
    assert_match(/'Card Number' should be a valid Credit Card/, response.message)
    assert_equal '10001', response.error_code
  end

  def test_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CVV not processed', response.cvv_result['message']
    assert_equal 'P', response.cvv_result['code']
  end

  def test_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Address not verified.', response.avs_result['message']
    assert_equal 'I', response.avs_result['code']
  end

  def test_failed_echeck_purchase
    response = @gateway.purchase(@amount, @invalid_check, @options.merge(@valid_check_options))
    assert_failure response
    assert_match(/ECP data validity check failed/, response.message)
    assert_equal '10001', response.error_code
  end

  def test_failed_unauthorized_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options.merge({ authorized_by_shopper: false }))
    assert_failure response
    assert_match(/The payment was not authorized by shopper/, response.message)
    assert_equal '16004', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_successful_authorize_and_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_successful_authorize_and_capture_with_3ds2_auth
    auth = @gateway.authorize(@amount, @three_ds_master_card, @options_3ds2)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Authorization has failed for this transaction/, response.message)
  end

  def test_partial_capture_succeeds_even_though_amount_is_ignored_by_gateway
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match(/due to missing transaction ID/, response.message)
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_match(/cannot be completed due to missing transaction ID/, response.message)
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match(/cannot be completed due to missing transaction ID/, response.message)
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match(/Transaction failed  because of payment processing failure/, response.message)
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'Success', response.message
    assert response.authorization
    assert_equal 'I', response.avs_result['code']
    assert_equal 'P', response.cvv_result['code']
    assert_match(/services\/2\/vaulted-shoppers/, response.params['content-location-header'])
  end

  def test_successful_echeck_store
    assert response = @gateway.store(@check, @options.merge(@valid_check_options))

    assert_success response
    assert_equal 'Success', response.message
    assert response.authorization
    assert_match(/services\/2\/vaulted-shoppers/, response.params['content-location-header'])
  end

  def test_failed_store
    assert response = @gateway.store(@invalid_card, @options)

    assert_failure response
    assert_match(/'Card Number' should be a valid Credit Card/, response.message)
    assert_equal '10001', response.error_code
  end

  def test_failed_echeck_store
    assert response = @gateway.store(@invalid_check, @options)

    assert_failure response
    assert_match(/ECP data validity check failed/, response.message)
    assert_equal '10001', response.error_code
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_using_stored_echeck
    assert store_response = @gateway.store(@check, @options.merge(@valid_check_options))
    assert_success store_response
    assert_match(/check/, store_response.authorization)

    response = @gateway.purchase(@amount, store_response.authorization, @options.merge({ authorized_by_shopper: true }))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.authorize(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_invalid_login
    gateway = BlueSnapGateway.new(api_username: 'unknown', api_password: 'unknown')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Unable to authenticate.  Please check your credentials.', response.message
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = BlueSnapGateway.new(api_username: 'unknown', api_password: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_password], transcript)
  end

  def test_transcript_scrubbing_with_echeck
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @valid_check_options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:api_password], transcript)
  end

  def test_successful_purchase_with_idempotency_key
    response = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: 'test123'))
    assert_success response
    assert_equal 'Success', response.message
  end
end
