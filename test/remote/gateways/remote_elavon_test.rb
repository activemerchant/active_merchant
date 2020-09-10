require 'test_helper'

class RemoteElavonTest < Test::Unit::TestCase
  def setup
    @gateway = ElavonGateway.new(fixtures(:elavon))
    @multi_currency_gateway = ElavonGateway.new(fixtures(:elavon_multi_currency))

    @credit_card = credit_card('4124939999999990')
    @bad_credit_card = credit_card('invalid')

    @options = {
      email: 'paul@domain.com',
      description: 'Test Transaction',
      billing_address: address,
      ip: '203.0.113.0',
      merchant_initiated_unscheduled: 'N'
    }
    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)

    assert_failure response
    assert response.test?
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVAL', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(credit_card: @credit_card))
    assert_success capture
  end

  def test_authorize_and_capture_with_auth_code
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVAL', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, '', credit_card: @credit_card)
    assert_failure response
    assert_equal 'The FORCE Approval Code supplied in the authorization request appears to be invalid or blank.  The FORCE Approval Code must be 6 or less alphanumeric characters.', response.message
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_failed_verify
    assert response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{appears to be invalid}, response.message
  end

  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert credit.authorization
  end

  def test_purchase_and_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert refund.authorization
  end

  def test_purchase_and_failed_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount + 5, purchase.authorization)
    assert_failure refund
    assert_match %r{exceed}i, refund.message
  end

  def test_purchase_and_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert response = @gateway.void(purchase.authorization)

    assert_success response
    assert response.authorization
  end

  def test_purchase_and_unsuccessful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert @gateway.void(purchase.authorization)
    assert response = @gateway.void(purchase.authorization)
    assert_failure response
    assert_equal 'The transaction ID is invalid for this transaction type', response.message
  end

  def test_authorize_and_successful_void
    assert authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    assert response = @gateway.void(authorize.authorization)

    assert_success response
    assert response.authorization
  end

  def test_successful_store_without_verify
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_nil response.message
    assert response.test?
  end

  def test_successful_store_with_verify_false
    assert response = @gateway.store(@credit_card, @options.merge(verify: false))
    assert_success response
    assert_nil response.message
    assert response.test?
  end

  def test_successful_store_with_verify_true
    assert response = @gateway.store(@credit_card, @options.merge(verify: true))
    assert_success response
    assert_equal 'APPROVAL', response.message
    assert response.test?
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@bad_credit_card, @options)
    assert_failure response
    assert_equal 'The Credit Card Number supplied in the authorization request appears to be invalid.', response.message
    assert response.test?
  end

  def test_successful_update
    store_response = @gateway.store(@credit_card, @options)
    token = store_response.params['token']
    credit_card = credit_card('4124939999999990', month: 10)
    assert response = @gateway.update(token, credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_update
    assert response = @gateway.update('ABC123', @credit_card, @options)
    assert_failure response
    assert_match %r{invalid}i, response.message
    assert response.test?
  end

  def test_successful_purchase_with_token
    store_response = @gateway.store(@credit_card, @options)
    token = store_response.params['token']
    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
  end

  def test_failed_purchase_with_token
    assert response = @gateway.purchase(@amount, 'ABC123', @options)
    assert_failure response
    assert response.test?
    assert_match %r{invalid}i, response.message
  end

  def test_successful_purchase_with_custom_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(custom_fields: {a_key: 'a value'}))

    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_failed_purchase_with_multi_currency_terminal_setting_disabled
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'USD', multi_currency: true))

    assert_failure response
    assert response.test?
    assert_equal 'Transaction currency is not allowed for this terminal.  Your terminal must be setup with Multi currency', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_multi_currency_gateway_setting
    assert response = @multi_currency_gateway.purchase(@amount, @credit_card, @options.merge(currency: 'JPY'))

    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_multi_currency_transaction_setting
    @multi_currency_gateway.options[:multi_currency] = false
    assert response = @multi_currency_gateway.purchase(@amount, @credit_card, @options.merge(currency: 'JPY', multi_currency: true))

    assert_success response
    assert response.test?
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_successful_purchase_with_level_3_fields
    level_3_data = {
      customer_code: 'bob',
      salestax: '3.45',
      salestax_indicator: 'Y',
      level3_indicator: 'Y',
      ship_to_zip: '12345',
      ship_to_country: 'US',
      shipping_amount: '1234',
      ship_from_postal_code: '54321',
      discount_amount: '5',
      duty_amount: '2',
      national_tax_indicator: '0',
      national_tax_amount: '10',
      order_date: '280810',
      other_tax: '3',
      summary_commodity_code: '123',
      merchant_vat_number: '222',
      customer_vat_number: '333',
      freight_tax_amount: '4',
      vat_invoice_number: '26',
      tracking_number: '45',
      shipping_company: 'UFedzon',
      other_fees: '2',
      line_items: [
        {
          description: 'thing',
          product_code: '23',
          commodity_code: '444',
          quantity: '15',
          unit_of_measure: 'kropogs',
          unit_cost: '4.5',
          discount_indicator: 'Y',
          tax_indicator: 'Y',
          discount_amount: '1',
          tax_rate: '8.25',
          tax_amount: '12',
          tax_type: 'state',
          extended_total: '500',
          total: '525',
          alternative_tax: '111'
        },
        {
          description: 'thing2',
          product_code: '23',
          commodity_code: '444',
          quantity: '15',
          unit_of_measure: 'kropogs',
          unit_cost: '4.5',
          discount_indicator: 'Y',
          tax_indicator: 'Y',
          discount_amount: '1',
          tax_rate: '8.25',
          tax_amount: '12',
          tax_type: 'state',
          extended_total: '500',
          total: '525',
          alternative_tax: '111'
        }
      ]
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(level_3_data: level_3_data))

    assert_success response
    assert_equal 'APPROVAL', response.message
    assert response.authorization
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
