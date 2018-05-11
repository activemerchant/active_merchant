require 'test_helper'

class RemotePayConexTest < Test::Unit::TestCase
  def setup
    @gateway = PayConexGateway.new(fixtures(:pay_conex))
    @credit_card = credit_card('4000100011112224')
    @check = check

    @amount = 100
    @failed_amount = 101

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      email: "joe@example.com"
    }
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = "447"
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_accesskey], transcript)
 end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINED", response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "APPROVED", auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "CAPTURED", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINED", response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
    assert_equal "CAPTURED", capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'UnknownAuth')
    assert_failure response
    assert_equal "Invalid token_id", response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal "VOID", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal "REFUND", refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount + 400, purchase.authorization)
    assert_failure response
    assert_equal "INVALID REFUND AMOUNT", response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "APPROVED", void.message
  end

  def test_failed_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    response = @gateway.void(auth.authorization)
    assert_success response

    response = @gateway.void(auth.authorization)
    assert_failure response
    assert_equal "TRANSACTION ID ALREADY REVERSED", response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_failed_verify
    response = @gateway.verify(credit_card("BogusCard"), @options)
    assert_failure response
    assert_equal "INVALID CARD NUMBER", response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert response.authorization
    assert_equal "2224", response.params["last4"]
  end

  def test_failed_store
    assert response = @gateway.store(credit_card("141241"))
    assert_failure response
    assert_equal "CARD DATA UNREADABLE", response.message
  end

  def test_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "CREDIT", response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, credit_card("12321"), @options)
    assert_failure response
    assert_equal "CARD DATA UNREADABLE", response.message
  end

  def test_successful_card_present_purchase
    response = @gateway.purchase(@amount, credit_card_with_track_data('4000100011112224'), @options)
    assert_success response
    assert_equal "APPROVED", response.message
  end

  def test_failed_card_present_purchase
    card = CreditCard.new(track_data: '%B37826310005^LOB^17001130504392?')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_equal "CARD DATA UNREADABLE", response.message
  end

  def test_successful_echeck_purchase
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'PENDING', response.message
    assert response.authorization
  end

  def test_failed_echeck_purchase
    response = @gateway.purchase(@amount, check(routing_number: "23433"), @options)
    assert_failure response
    assert_equal 'Invalid bank_routing_number', response.message
  end

  def test_invalid_login
    gateway = PayConexGateway.new(account_id: 'Unknown', api_accesskey: 'Incorrect')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid account_id", response.message
  end
end
