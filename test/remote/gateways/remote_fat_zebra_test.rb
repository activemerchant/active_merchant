require 'test_helper'

class RemoteFatZebraTest < Test::Unit::TestCase
  def setup
    @gateway = FatZebraGateway.new(fixtures(:fat_zebra))

    @amount = 100
    @credit_card = credit_card('5123456789012346')
    @declined_card = credit_card('4557012345678902')

    @options = {
      order_id: generate_unique_id,
      ip: '1.2.3.4'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_multi_currency_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'USD', response.params['response']['currency']
  end

  def test_unsuccessful_multi_currency_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'XYZ'))
    assert_failure response
    assert_match(/Currency XYZ is not valid for this merchant/, response.message)
  end

  def test_successful_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card, recurring: true)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_sans_cvv
    @credit_card.verification_value = nil
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'CVV is required', response.message
  end

  def test_successful_purchase_with_no_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_authorize_and_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'Approved', auth_response.message

    assert capture_response = @gateway.capture(@amount, auth_response.authorization, @options)
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
  end

  def test_multi_currency_authorize_and_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options.merge(currency: 'USD'))
    assert_success auth_response
    assert_equal 'Approved', auth_response.message
    assert_equal 'USD', auth_response.params['response']['currency']

    assert capture_response = @gateway.capture(@amount, auth_response.authorization, @options.merge(currency: 'USD'))
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
    assert_equal 'USD', capture_response.params['response']['currency']
  end

  def test_successful_partial_capture
    assert auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'Approved', auth_response.message

    assert capture_response = @gateway.capture(@amount - 1, auth_response.authorization, @options)
    assert_success capture_response
    assert_equal 'Approved', capture_response.message
    assert_equal @amount - 1, capture_response.params['response']['captured_amount']
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_invalid_refund
    @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_match %r{Invalid credit card for unmatched refund}, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)

    assert response = @gateway.void(auth.authorization, @options)
    assert_success response
    assert_match %r{Voided}, response.message
  end

  def test_successful_void_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund

    assert response = @gateway.void(refund.authorization, @options)
    assert_success response
    assert_match %r{Voided}, response.message
  end

  def test_failed_void
    assert response = @gateway.void('123', @options)
    assert_failure response
    assert_match %r{Not Found}, response.message
  end

  def test_store
    assert card = @gateway.store(@credit_card)

    assert_success card
    assert_not_nil card.authorization
  end

  def test_successful_store_without_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    assert card = @gateway.store(credit_card, recurring: true)

    assert_success card
    assert_not_nil card.authorization
  end

  def test_failed_store_without_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    assert card = @gateway.store(credit_card)

    assert_failure card
    assert_match %r{CVV is required}, card.message
  end

  def test_purchase_with_token
    assert card = @gateway.store(@credit_card)
    assert purchase = @gateway.purchase(@amount, card.authorization, @options.merge(cvv: 123))
    assert_success purchase
  end

  def test_successful_purchase_with_descriptor
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(merchant: 'Merchant', merchant_location: 'Location'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_metadata
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(metadata: { description: 'Invoice #1234356' }))
    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 'Invoice #1234356', response.params['response']['metadata']['description']
  end

  def test_successful_purchase_with_3DS_information
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(cavv: 'MDRjN2MxZTAxYjllNTBkNmM2MTA=', xid: 'MGVmMmNlMzI4NjAyOWU2ZDgwNTQ=', sli: '05'))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_with_incomplete_3DS_information
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(xid: 'MGVmMmNlMzI4NjAyOWU2ZDgwNTZ=', sli: '05'))
    assert_failure response
    assert_match %r{Extra/cavv is required for SLI 05}, response.message
  end

  def test_successful_purchase_with_3DS_information_using_standard_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(three_d_secure: { cavv: 'MDRjN2MxZTAxYjllNTBkNmM2MTA=', xid: 'MGVmMmNlMzI4NjAyOWU2ZDgwNTQ=', eci: '05' }))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase_with_incomplete_3DS_information_using_standard_fields
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(three_d_secure: { xid: 'MGVmMmNlMzI4NjAyOWU2ZDgwNTQ=', eci: '05' }))
    assert_failure response
    assert_match %r{Extra/cavv is required for SLI 05}, response.message
  end

  def test_successful_purchase_with_card_on_file_information
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(recurring: true, extra: { card_on_file: true, auth_reason: 'U' }))
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_invalid_login
    gateway = FatZebraGateway.new(
      username: 'invalid',
      token: 'wrongtoken'
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid Login', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end
