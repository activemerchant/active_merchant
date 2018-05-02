require 'test_helper'

class RemoteWorldNetTest < Test::Unit::TestCase
  def setup
    @gateway = WorldNetGateway.new(fixtures(:world_net))

    @amount = 100
    @declined_amount = 101
    @credit_card = credit_card('3779810000000005')
    @options = {
      order_id: generate_order_id,
    }
    @refund_options = {
      operator: 'mr.nobody',
      reason: 'returned'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: generate_order_id,
      email: "joe@example.com",
      billing_address: address,
      description: 'Store Purchase',
      ip: "127.0.0.1",
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code

    response = @gateway.purchase(103, @credit_card, @options)
    assert_failure response
    assert_equal 'CVV FAILURE', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_cvc], response.error_code

    response = @gateway.purchase(@amount, credit_card('3779810000000005', month: '13'), @options)
    assert_failure response
    assert_equal 'Invalid CARDEXPIRY field', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'APPROVAL', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match %r{not facet-valid with respect to minLength}, response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @refund_options)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @refund_options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @refund_options)
    assert_failure response
    assert_match %r{not facet-valid with respect to minLength}, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
  # UNSUPPORTED
  #   assert_success void
  #   assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', response.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match %r{Cannot find the declaration of element}, response.message
  end

  def test_invalid_login
    gateway = WorldNetGateway.new(terminal_id: '', secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{not facet-valid with respect to minLength}, response.message
  end

  def test_successful_store
    store = @gateway.store(@credit_card, @options)
    assert_success store
  end

  def test_unsuccessful_store
    store = @gateway.store(credit_card('3779810000000005', month: '13'), @options)
    assert_failure store
  end

  def test_successful_unstore
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal nil, response.message
    card_reference = response.authorization

    assert response = @gateway.unstore(card_reference, @options)
    assert_success response

    assert response = @gateway.purchase(@amount, card_reference, @options)
    assert_failure response
  end

  def test_unsuccessful_unstore
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal nil, response.message
    card_reference = response.authorization

    assert response = @gateway.unstore('123456789', @options)
    assert_failure response
  end

  def test_purchase_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal nil, response.message
    card_reference = response.authorization

    assert response = @gateway.purchase(@amount, card_reference, @options)
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret], transcript)
  end

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
