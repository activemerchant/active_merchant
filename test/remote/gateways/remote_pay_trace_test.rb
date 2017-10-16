require 'test_helper'

class RemotePayTraceTest < Test::Unit::TestCase
  # These remote tests will run with `minimum required options` and `required options
  # if configured (invoice, billing address, billing zip, csc)` in the PayTrace Web Portal.
  #
  # To 100% remote tests, go to PayTrace Web Portal to adjust values for testing:
  # Account > Security Settings >
  #   - Duplicate Transaction Time: 0
  #     Setting value to '0' will prevent tests from failing due to duplicate transactions.
  #
  #   - Enable Phishing Filter: No
  #     If enabled, this filter will return a message on the third unsuccessful transaction
  #     processed on the same card number in a rolling 24 hour window and disable the card
  #     number on the fourth failed attempt.
  #
  #   - Require Invoice: No
  #   - Require Billing Address: No
  #   - Require Billing Zip: No
  #   - Require CSC: No
  #
  def setup
    @gateway = PayTraceGateway.new(fixtures(:pay_trace))
    @amount = 100.00
    @declined_amount = 112.00
    @visa_credit_card = credit_card('4012000098765439', verification_value: 999)

    # In the PayTrace Web Portal, there are three options that
    # would be required if configured:
    #
    # options: invoice_id, billing_address, csc (card verification value)
    @required_if_configured_options = {
      invoice_id: generate_unique_id,
      billing_address: address(city: 'Spokane', state: 'WA', zip: '99201', country: 'US')}
    @card_verification_value = { card_verification_value: @visa_credit_card.verification_value.to_s }

    @options = {
      invoice_id: generate_unique_id,
      customer_reference_id: "PO ##{generate_unique_id}",
      email: "arty@example.com",
      description: "PayTrace Gateway"
    }
    @level_data_options = {
      invoice_id: "inv1234",
      customer_reference_id: "PO123456",
      tax_amount: 8.10,
      national_tax_amount: 0.00,
      freight_amount: 0.00,
      duty_amount: 0.00,
      source_address: {
          zip: "99201"
      },
      shipping_address: {
           zip: "85284",
           country: "US"
      },
      additional_tax_amount: 0.00,
      additional_tax_included: true,
      line_items: [{
          additional_tax_amount: 0.40,
          additional_tax_included: true,
          additional_tax_rate: 0.08,
          amount: 1.00,
          debit_or_credit: "C",
          description: "business services",
          discount_amount: 3.27,
          discount_rate: 0.01,
          discount_included: true,
          merchant_tax_id: "12-123456",
          product_id: "sku1245",
          quantity: 1,
          tax_included: true,
          unit_of_measure: "EACH",
          unit_cost: 5.24
      }]
    }
  end


  # PURCHASE (WITH CARD)
  # --------------------------------------------------------------------------------
  def test_successful_purchase
    response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_with_other_required_fields
    response = @gateway.purchase(@amount, @visa_credit_card, @required_if_configured_options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_with_options
    response = @gateway.purchase(@amount, @visa_credit_card, @options)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @visa_credit_card, {invoice_id: generate_unique_id})
    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  # PURCHASE (BY TRANSACTION)
  # --------------------------------------------------------------------------------
  def test_successful_purchase_by_transaction
    past_purchase_response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success past_purchase_response

    response = @gateway.purchase(400, past_purchase_response.authorization)
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_successful_purchase_by_transaction_with_other_required_fields
    past_purchase_response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success past_purchase_response

    response = @gateway.purchase(400, past_purchase_response.authorization, @required_if_configured_options.merge(@card_verification_value))
    assert_success response
    assert_equal 'Your transaction was successfully approved.', response.message
  end

  def test_failed_purchase_by_transaction
    past_purchase_response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success past_purchase_response

    response = @gateway.purchase(@declined_amount, past_purchase_response.authorization)
    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  # AUTHORIZE / CAPTURE
  # --------------------------------------------------------------------------------
  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @visa_credit_card)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Your transaction was successfully captured.', capture.message
  end

  def test_successful_authorize_and_capture_with_other_required_fields
    auth = @gateway.authorize(@amount, @visa_credit_card, @required_if_configured_options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Your transaction was successfully captured.', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @visa_credit_card)
    assert_failure response
    assert_equal 'Your transaction was not approved.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @visa_credit_card)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@declined_amount, '')
    assert_failure response
    assert_equal '811', response.error_code
  end

  # AUTHORIZE (BY TRANSACTION) / CAPTURE
  # --------------------------------------------------------------------------------
  def test_successful_authorize_and_capture_with_transaction
    past_purchase_response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success past_purchase_response

    auth = @gateway.authorize(@amount, past_purchase_response.authorization)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Your transaction was successfully captured.', capture.message
  end

  def test_successful_authorize_and_capture_with_transaction_and_other_required_fields
    past_purchase_response = @gateway.purchase(@amount, @visa_credit_card)
    assert_success past_purchase_response

    auth = @gateway.authorize(@amount, past_purchase_response.authorization, @required_if_configured_options.merge(@card_verification_value))
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Your transaction was successfully captured.', capture.message
  end

  # REFUND (BY CARD)
  # --------------------------------------------------------------------------------
  def test_successful_refund
    assert refund = @gateway.refund(@amount, @visa_credit_card)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_successful_refund_with_other_required_fields
    assert refund = @gateway.refund(@amount, @visa_credit_card, @required_if_configured_options)
    assert_success refund
    assert_equal 'Your transaction was successfully refunded.', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@declined_amount, '')
    assert_failure response
    assert_equal '811', response.error_code
  end

  # REFUND (BY TRANSACTION)
  # --------------------------------------------------------------------------------
  #
  # Notes: Only settled transactions can be refunded.
  #
  # def test_successful_refund_transaction
  #   # Replace value with transaction id that has been settled.
  #   settled_transaction_id = TRANSACTION-NUMBER-HERE
  #
  #   assert refund = @gateway.refund(@amount, settled_transaction_id)
  #   assert_success refund
  #   assert_equal 'Your transaction was successfully refunded.', refund.message
  # end
  #
  # def test_partial_refund_transaction
  #   # Replace value with transaction id that has been settled.
  #   settled_transaction_id = TRANSACTION-NUMBER-HERE
  #
  #   assert refund = @gateway.refund(@amount-1, settled_transaction_id)
  #   assert_success refund
  # end

  # VOID
  # --------------------------------------------------------------------------------
  #
  # Notes: Only unsettled transactions can be voided.
  #
  def test_successful_void
    auth = @gateway.authorize(@amount, @visa_credit_card)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Your transaction was successfully voided.', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal '811', response.error_code
  end

  # VERIFY
  # --------------------------------------------------------------------------------
  def test_successful_verify
    response = @gateway.verify(@visa_credit_card)
    assert_success response
    assert_match 'Your transaction was successfully approved.', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card)
    assert_failure response
  end

  # LEVEL 3 DATA
  # --------------------------------------------------------------------------------
  def test_successful_add_level_3_data_visa
    purch = @gateway.purchase(@amount, @visa_credit_card)
    assert_success purch

    response = @gateway.add_level_3_data(purch.authorization, @level_data_options)
    assert_success response
    assert_equal "Visa/MasterCard enhanced data was successfully added to Transaction ID #{purch.authorization}. 1 line item records were created.", response.message
  end

  def test_successful_add_level_3_data_mastercard
    mastercard = credit_card('5499740000000057', verification_value: 998, brand: 'master')
    purch = @gateway.purchase(@amount, mastercard)
    assert_success purch

    response = @gateway.add_level_3_data(purch.authorization, @level_data_options.merge({brand: mastercard.brand}))
    assert_success response
    assert_equal "Visa/MasterCard enhanced data was successfully added to Transaction ID #{purch.authorization}. 1 line item records were created.", response.message
  end

  def test_failed_add_level_3_data
    response = @gateway.add_level_3_data('', @level_data_options)
    assert_failure response
    assert_equal '58', response.error_code
  end

  # SCRUBBING
  # --------------------------------------------------------------------------------
  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @visa_credit_card)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visa_credit_card.number, transcript)
    assert_scrubbed(@visa_credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:username], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  # LOGIN
  # --------------------------------------------------------------------------------
  def test_invalid_login
    gateway = PayTraceGateway.new(username: '', password: '')
    response = gateway.purchase(@amount, @visa_credit_card)
    assert_failure response
    assert_match 'The provided authorization grant is invalid, expired, revoked, does not match the redirection URI used in the authorization request, or was issued to another client.', response.message
  end
end