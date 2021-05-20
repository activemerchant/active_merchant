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
    @discover = credit_card('6011000993026909')
    @amex = credit_card('371449635392376')
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
    response = @gateway.purchase(@amount, @credit_card, @options)
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

  def test_successful_purchase_with_more_options
    options = {
      email: 'joe@example.com'
    }

    response = @gateway.purchase(200, @discover, options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(29, @amex, @options)
    assert_failure response
    assert_equal false, response.success?
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(300, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(auth.authorization, @options.merge(amount: 300))
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

  def test_failed_authorize
    response = @gateway.authorize(29, @mastercard, @options)
    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(500, @amex, @options)
    assert_success auth

    assert capture = @gateway.capture(auth.authorization, @options.merge(amount: 300))
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture('')
    assert_failure response
    assert_equal 'One or more errors has occurred.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(200, @credit_card, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(authorization, @options.merge(amount: 200))
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(400, @mastercard, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(authorization, @options.merge(amount: 300))
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_refund_without_amount
    purchase = @gateway.purchase(@amount, @discover, @options)
    assert_success purchase
    authorization = purchase.authorization

    settle = @gateway.settle()
    assert_success settle

    refund = @gateway.refund(authorization)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_failed_refund
    response = @gateway.refund('', @options)
    assert_failure response
    assert_equal 'One or more errors has occurred.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @amex, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Your transaction was successfully voided.', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'One or more errors has occurred.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@mastercard, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_store_and_redact_customer_profile
    response = @gateway.store(@mastercard, @options)
    assert_success response
    customer_id = response.params['customer_id']
    redact = @gateway.redact(customer_id)
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
