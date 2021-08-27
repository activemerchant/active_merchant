require 'test_helper'

class RemoteCardStreamTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = CardStreamGateway.new(fixtures(:card_stream))

    @amex = credit_card('374245455400001',
      month: '12',
      year: Time.now.year + 1,
      verification_value: '4887',
      brand: :american_express)

    @mastercard = credit_card('5301250070000191',
      month: '12',
      year: Time.now.year + 1,
      verification_value: '419',
      brand: :master)

    @visacreditcard = credit_card('4929421234600821',
      month: '12',
      year: Time.now.year + 1,
      verification_value: '356',
      brand: :visa)

    @visadebitcard = credit_card('4539791001730106',
      month: '12',
      year: Time.now.year + 1,
      verification_value: '289',
      brand: :visa)

    @declined_card = credit_card('4000300011112220',
      month: '9',
      year: Time.now.year + 1)

    @amex_options = {
      billing_address: {
        address1: 'The Hunts Way',
        city: '',
        state: 'Leicester',
        zip: 'SO18 1GW',
        country: 'GB'
      },
      order_id: generate_unique_id,
      description: 'AM test purchase',
      ip: '1.1.1.1'
    }

    @visacredit_options = {
      billing_address: {
        address1: 'Flat 6, Primrose Rise',
        address2: '347 Lavender Road',
        city: '',
        state: 'Northampton',
        zip: 'NN17 8YG',
        country: 'GB'
      },
      order_id: generate_unique_id,
      description: 'AM test purchase',
      ip: '1.1.1.1'
    }

    @visacredit_descriptor_options = {
      billing_address: {
        address1: 'Flat 6, Primrose Rise',
        address2: '347 Lavender Road',
        city: '',
        state: 'Northampton',
        zip: 'NN17 8YG',
        country: 'GB'
      },
      order_id: generate_unique_id,
      merchant_name: 'merchant',
      dynamic_descriptor: 'product',
      ip: '1.1.1.1'
    }

    @visacredit_reference_options = {
      order_id: generate_unique_id,
      description: 'AM test purchase',
      ip: '1.1.1.1'
    }

    @visadebit_options = {
      billing_address: {
        address1: 'Unit 5, Pickwick Walk',
        address2: '120 Uxbridge Road',
        city: 'Hatch End',
        state: 'Middlesex',
        zip: 'HA6 7HJ',
        country: 'GB'
      },
      order_id: generate_unique_id,
      description: 'AM test purchase',
      ip: '1.1.1.1'
    }

    @mastercard_options = {
      billing_address: {
        address1: '25 The Larches',
        city: 'Narborough',
        state: 'Leicester',
        zip: 'LE10 2RT',
        country: 'GB'
      },
      order_id: generate_unique_id,
      description: 'AM test purchase',
      ip: '1.1.1.1'
    }

    @three_ds_enrolled_card = credit_card('4012001037141112',
      month: '12',
      year: '2020',
      brand: :visa)
  end

  def test_successful_visacreditcard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visacreditcard_authorization_and_capture_no_billing_address
    assert responseAuthorization = @gateway.authorize(142, @visacreditcard, @visacredit_options.delete(:billing_address))
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visacreditcard_purchase_and_refund_with_force_refund
    assert responsePurchase = @gateway.purchase(284, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @visacredit_options.merge(force_full_refund_if_unsettled: true))
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_failed_visacreditcard_purchase_and_refund
    assert responsePurchase = @gateway.purchase(284, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @visacredit_options)
    assert_failure responseRefund
    assert_equal 'Cannot REFUND this SALE transaction', responseRefund.message
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_purchase_with_dynamic_descriptors
    assert responsePurchase = @gateway.purchase(284, @visacreditcard, @visacredit_descriptor_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?
  end

  def test_successful_visacreditcard_authorization_and_void
    assert responseAuthorization = @gateway.authorize(284, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseVoid = @gateway.void(responseAuthorization.authorization, @visacredit_options)
    assert_equal 'APPROVED', responseVoid.message
    assert_success responseVoid
    assert responseVoid.test?
  end

  def test_successful_visadebitcard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @visadebit_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_visadebitcard_purchase_and_refund_with_force_refund
    assert responsePurchase = @gateway.purchase(284, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @visadebit_options.merge(force_full_refund_if_unsettled: true))
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_failed_visadebitcard_purchase_and_refund
    assert responsePurchase = @gateway.purchase(284, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @visadebit_options)
    assert_equal 'Cannot REFUND this SALE transaction', responseRefund.message
    assert_failure responseRefund
    assert responseRefund.test?
  end

  def test_successful_amex_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @amex, @amex_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @amex_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_amex_purchase_and_refund_with_force_refund
    assert responsePurchase = @gateway.purchase(284, @amex, @amex_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @amex_options.merge(force_full_refund_if_unsettled: true))
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_failed_amex_purchase_and_refund
    assert responsePurchase = @gateway.purchase(284, @amex, @amex_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @amex_options)
    assert_equal 'Cannot REFUND this SALE transaction', responseRefund.message
    assert_failure responseRefund
    assert responseRefund.test?
  end

  def test_successful_mastercard_authorization_and_capture
    assert responseAuthorization = @gateway.authorize(142, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', responseAuthorization.message
    assert_success responseAuthorization
    assert responseAuthorization.test?
    assert !responseAuthorization.authorization.blank?
    assert responseCapture = @gateway.capture(142, responseAuthorization.authorization, @mastercard_options)
    assert_equal 'APPROVED', responseCapture.message
    assert_success responseCapture
    assert responseCapture.test?
  end

  def test_successful_mastercard_purchase_and_refund_with_force_refund
    assert responsePurchase = @gateway.purchase(284, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @mastercard_options.merge(force_full_refund_if_unsettled: true))
    assert_equal 'APPROVED', responseRefund.message
    assert_success responseRefund
    assert responseRefund.test?
  end

  def test_failed_mastercard_purchase_and_refund
    assert responsePurchase = @gateway.purchase(284, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', responsePurchase.message
    assert_success responsePurchase
    assert responsePurchase.test?
    assert !responsePurchase.authorization.blank?

    assert responseRefund = @gateway.refund(142, responsePurchase.authorization, @mastercard_options)
    assert_equal 'Cannot REFUND this SALE transaction', responseRefund.message
    assert_failure responseRefund
    assert responseRefund.test?
  end

  def test_successful_visacreditcard_purchase
    assert response = @gateway.purchase(142, @visacreditcard, @visacredit_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_visacreditcard_purchase_via_reference
    assert response = @gateway.purchase(142, @visacreditcard, @visacredit_options.merge({ type: '9' }))
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.purchase(142, response.authorization, @visacredit_reference_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
  end

  def test_failed_visacreditcard_purchase_via_reference
    assert response = @gateway.purchase(142, 123, @visacredit_reference_options)
    assert_match %r{INVALID_XREF}, response.message
    assert_failure response
    assert response.test?
  end

  def test_purchase_no_currency_specified_defaults_to_GBP
    assert response = @gateway.purchase(142, @visacreditcard, @visacredit_options.merge(currency: nil))
    assert_success response
    assert_equal '826', response.params['currencyCode']
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase_non_existent_currency
    assert response = @gateway.purchase(142, @visacreditcard, @visacredit_options.merge(currency: 'CEO'))
    assert_failure response
    assert_match %r{MISSING_CURRENCYCODE}, response.message
  end

  def test_successful_purchase_and_amount_for_non_decimal_currency
    assert response = @gateway.purchase(14200, @visacreditcard, @visacredit_options.merge(currency: 'JPY'))
    assert_success response
    assert_equal '392', response.params['currencyCode']
    assert_equal '142', response.params['amount']
  end

  def test_successful_visadebitcard_purchase
    assert response = @gateway.purchase(142, @visadebitcard, @visadebit_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(142, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_declined_mastercard_purchase
    assert response = @gateway.purchase(10000, @mastercard, @mastercard_options)
    assert_equal 'CARD DECLINED', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_amex_purchase
    assert response = @gateway.purchase(142, @amex, @amex_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_invalid_login
    gateway = CardStreamGateway.new(
      login: '',
      shared_secret: ''
    )
    assert response = gateway.purchase(142, @mastercard, @mastercard_options)
    assert_match %r{MISSING_MERCHANTID}, response.message
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@mastercard, @mastercard_options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @mastercard_options)
    assert_failure response
    assert_match %r{Disallowed cardnumber}, response.message
  end

  def test_successful_3dsecure_purchase
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @mastercard_options.merge(threeds_required: true))
    assert_equal '3DS AUTHENTICATION REQUIRED', response.message
    assert_equal '65802', response.params['responseCode']
    assert response.test?
    assert !response.authorization.blank?
    assert !response.params['threeDSACSURL'].blank?
    assert !response.params['threeDSMD'].blank?
    assert !response.params['threeDSPaReq'].blank?
  end

  def test_successful_3dsecure_auth
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @mastercard_options.merge(threeds_required: true))
    assert_equal '3DS AUTHENTICATION REQUIRED', response.message
    assert_equal '65802', response.params['responseCode']
    assert response.test?
    assert !response.authorization.blank?
    assert !response.params['threeDSACSURL'].blank?
    assert !response.params['threeDSMD'].blank?
    assert !response.params['threeDSPaReq'].blank?
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @visacreditcard, @visacredit_options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@visacreditcard.number, clean_transcript)
    assert_scrubbed(@visacreditcard.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:shared_secret], clean_transcript)
  end
end
