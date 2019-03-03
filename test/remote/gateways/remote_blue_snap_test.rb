require 'test_helper'

class RemoteBlueSnapTest < Test::Unit::TestCase
  def setup
    @gateway = BlueSnapGateway.new(fixtures(:blue_snap))

    @amount = 100
    @credit_card = credit_card('4263982640269299')
    @declined_card = credit_card('4917484589897107', month: 1, year: 2023)
    @invalid_card = credit_card('4917484589897106', month: 1, year: 2023)
    @options = { billing_address: address }

    @check = check
    @invalid_check = check(:routing_number => '123456', :account_number => '123456789')
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

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options.merge(@valid_check_options))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Authorization has failed for this transaction/, response.message)
    assert_equal '14002', response.error_code
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
    response = @gateway.purchase(@amount, @check, @options.merge({authorized_by_shopper: false}))
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

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Authorization has failed for this transaction/, response.message)
  end

  def test_partial_capture_succeeds_even_though_amount_is_ignored_by_gateway
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
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

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
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

    response = @gateway.purchase(@amount, store_response.authorization, @options.merge({authorized_by_shopper: true}))
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

end
