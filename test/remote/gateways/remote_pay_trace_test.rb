require 'test_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayTraceGateway < Gateway
      def settle
        post = {}
        response = commit('transactions/settle', post)
        check_token_response(response, 'transactions/settle', post, options)
      end
    end
  end
end

class RemotePayTraceTest < Test::Unit::TestCase
  def setup
    @gateway = PayTraceGateway.new(fixtures(:pay_trace))

    @amount = 100
    @credit_card = credit_card('4012000098765439')
    @mastercard = credit_card('5499740000000057')
    @invalid_card = credit_card('54545454545454', month: '14', year: '1999')
    @discover = credit_card('6011000993026909')
    @amex = credit_card('371449635392376')
    @echeck = check(account_number: '123456', routing_number: '325070760')
    @options = {
      billing_address: {
        address1: '8320 This Way Lane',
        city: 'Placeville',
        state: 'CA',
        zip: '85284'
      },
      description: 'Store Purchase'
    }
  end

  def test_acquire_token
    response = @gateway.acquire_access_token
    assert_not_nil response['access_token']
  end

  def test_successful_purchase
    response = @gateway.purchase(1000, @credit_card, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_with_customer_id
    create = @gateway.store(@mastercard, @options)
    customer_id = create.params['customer_id']
    response = @gateway.purchase(500, customer_id, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_with_ach
    @echeck.account_number = rand.to_s[2..7]
    response = @gateway.purchase(1000, @echeck, @options)
    assert_success response
    assert_equal response.message, 'Your check was successfully processed.'
  end

  def test_successful_purchase_by_customer_with_ach
    @echeck.account_number = rand.to_s[2..7]
    create = @gateway.store(@echeck, @options)
    assert_success create
    customer_id = create.params['customer_id']
    response = @gateway.purchase(500, customer_id, @options.merge({ check_transaction: 'true' }))
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = {
      email: 'joe@example.com'
    }

    response = @gateway.purchase(200, @discover, options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_with_level_3_data_visa
    options = {
      visa_or_mastercard: 'visa',
      invoice_id: 'inv12345',
      customer_reference_id: '123abcd',
      tax_amount: 499,
      national_tax_amount: 172,
      merchant_tax_id: '3456defg',
      customer_tax_id: '3456test',
      commodity_code: '4321',
      discount_amount: 99,
      freight_amount: 75,
      duty_amount: 32,
      source_address: {
        zip: '94947'
      },
      shipping_address: {
        zip: '94948',
        country: 'US'
      },
      additional_tax_amount: 4,
      additional_tax_rate: 1,
      line_items: [
        {
          additional_tax_amount: 0,
            additional_tax_rate: 8,
            amount: 1999,
            commodity_code: '123commodity',
            description: 'plumbing',
            discount_amount: 327,
            product_id: 'skucode123',
            quantity: 4,
            unit_of_measure: 'EACH',
            unit_cost: 424
        }
      ]
    }

    response = @gateway.purchase(3000, @credit_card, options)
    assert_success response
    assert_equal 101, response.params['response_code']
    assert_not_nil response.authorization
  end

  def test_successful_purchase_with_level_3_data_mastercard
    options = {
      visa_or_mastercard: 'mastercard',
      invoice_id: 'inv1234',
      customer_reference_id: 'PO123456',
      tax_amount: 810,
      source_address: {
        zip: '99201'
      },
      shipping_address: {
        zip: '85284',
        country: 'US'
      },
      additional_tax_amount: 40,
      additional_tax_included: true,
      line_items: [
        {
          additional_tax_amount: 40,
          additional_tax_included: true,
          additional_tax_rate: 8,
          amount: 1999,
          debit_or_credit: 'D',
          description: 'business services',
          discount_amount: 327,
          discount_rate: 1,
          discount_included: true,
          merchant_tax_id: '12-123456',
          product_id: 'sku1245',
          quantity: 4,
          tax_included: true,
          unit_of_measure: 'EACH',
          unit_cost: 524
        }
      ]
    }

    response = @gateway.purchase(250, @mastercard, options)
    assert_success response
    assert_equal 101, response.params['response_code']
  end

  # Level three data can only be added to approved sale transactions done with visa or mastercard.
  # This test is to show that if a transaction were to come through with a different card type,
  # the gateway integration would ignore the attempt to add level three data, but could still approve the sale transaction.
  def test_successful_purchase_with_attempted_level_3
    options = {
      visa_or_mastercard: 'discover',
      invoice_id: 'inv1234',
      customer_reference_id: 'PO123456'
    }

    response = @gateway.purchase(300, @discover, @options.merge(options))
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(29, @amex, @options)
    assert_failure response
    assert_equal false, response.success?
  end

  def test_failed_purchase_with_multiple_errors
    response = @gateway.purchase(25000, @invalid_card, @options)
    assert_failure response
    assert_equal 'Errors- code:35, message:["Please provide a valid Credit Card Number."] code:43, message:["Please provide a valid Expiration Month."]', response.message
  end

  def test_successful_authorize_and_full_capture
    auth = @gateway.authorize(4000, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(4000, auth.authorization, @options)
    assert_success capture
    assert_equal 'Your transaction was successfully captured.', capture.message
  end

  def test_successful_authorize_with_customer_id
    store = @gateway.store(@mastercard, @options)
    assert_success store
    customer_id = store.params['customer_id']

    response = @gateway.authorize(200, customer_id, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_authorize_with_ach
    @echeck.account_number = rand.to_s[2..7]
    response = @gateway.authorize(1000, @echeck, @options)
    assert_success response
    assert_equal response.message, 'Your check was successfully processed.'
  end

  def test_successful_authorize_by_customer_with_ach
    @echeck.account_number = rand.to_s[2..7]
    store = @gateway.store(@echeck, @options)
    assert_success store
    customer_id = store.params['customer_id']

    response = @gateway.authorize(200, customer_id, @options.merge({ check_transaction: 'true' }))
    assert_success response
  end

  def test_successful_authorize_and_capture_with_level_3_data
    options = {
      visa_or_mastercard: 'mastercard',
      address: {
        zip: '99201'
      },
      shipping_address: {
        zip: '85284',
        country: 'US'
      },
      line_items: [
        {
          description: 'office supplies',
          product_id: 'sku9876'
        },
        {
          description: 'business services',
          product_id: 'sku3456'
        }
      ]
    }
    auth = @gateway.authorize(@amount, @mastercard, options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, options)
    assert_success capture

    transaction_id = auth.authorization
    assert_equal "Visa/MasterCard enhanced data was successfully added to Transaction ID #{transaction_id}. 2 line item records were created.", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(29, @mastercard, @options)
    assert_failure response
    assert_equal 'Your transaction was not approved.   EXPIRED CARD - Expired card', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(500, @amex, @options)
    assert_success auth

    assert capture = @gateway.capture(200, auth.authorization, @options)
    assert_success capture
  end

  def test_authorize_and_capture_with_ach
    @echeck.account_number = rand.to_s[2..7]
    auth = @gateway.authorize(500, @echeck, @options)
    assert_success auth

    assert capture = @gateway.capture(500, auth.authorization, @options.merge({ check_transaction: 'true' }))
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Errors- code:58, message:["Please provide a valid Transaction ID."]', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(200, @credit_card, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(200, authorization, @options)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(400, @mastercard, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(300, authorization, @options)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_refund_without_amount
    purchase = @gateway.purchase(@amount, @discover, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(@amount, authorization)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(2000, @credit_card, @options)
    assert_success purchase
    authorization = purchase.authorization

    response = @gateway.refund(2000, authorization, @options)
    assert_failure response
    assert_equal 'Errors- code:817, message:["The Transaction ID that you provided could not be refunded. Only settled transactions can be refunded.  Please try to void the transaction instead."]', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @amex, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Your transaction was successfully voided.', void.message
  end

  def test_successful_void_with_ach
    @echeck.account_number = rand.to_s[2..7]
    auth = @gateway.authorize(@amount, @echeck, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, { check_transaction: 'true' })
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Errors- code:58, message:["Please provide a valid Transaction ID."]', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@mastercard, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_successful_store_and_redact_customer_profile
    response = @gateway.store(@mastercard, @options)
    assert_success response
    customer_id = response.params['customer_id']
    redact = @gateway.unstore(customer_id)
    assert_success redact
    assert_equal true, redact.success?
  end

  def test_duplicate_customer_creation
    create = @gateway.store(@discover, @options)
    customer_id = create.params['customer_id']
    response = @gateway.store(@discover, @options.merge(customer_id: customer_id))
    assert_failure response
  end

  # Not including a test_failed_verify since the only way to force a failure on this
  # gateway is with a specific dollar amount. Since verify is auth and void combined,
  # having separate tests for auth and void should suffice.

  def test_invalid_login
    gateway = PayTraceGateway.new(username: 'username', password: 'password', integrator_id: 'integrator_id')

    response = gateway.acquire_access_token
    assert_match 'invalid_grant', response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @amex, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@amex.number, transcript)
    assert_scrubbed(@amex.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:username], transcript)
    assert_scrubbed(@gateway.options[:integrator_id], transcript)
  end
end
