require 'test_helper'

class RemoteProPayTest < Test::Unit::TestCase
  def setup
    @gateway = ProPayGateway.new(fixtures(:pro_pay))

    @amount = 100
    @credit_card = credit_card('4747474747474747', verification_value: 999)
    @declined_card = credit_card('4616161616161616')
    @credit_card_without_cvv = credit_card('4747474747474747', verification_value: nil)
    @options = {
      billing_address: address,
      account_num: "32287391"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      account_num: "32287391"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_recurring_purchase_without_cvv
    @options.merge!({recurring_payment: 'Y'})
    response = @gateway.purchase(@amount, @credit_card_without_cvv, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/declined/, response.message)
    assert_match(/Insufficient funds/, response.message)
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/declined/, response.message)
    assert_match(/Insufficient funds/, response.message)
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_match(/Invalid/, response.message)
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

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_match(/Invalid/, response.message)
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void
    response = @gateway.void('', @options)
    assert_failure response
    assert_match(/Invalid/, response.message)
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, credit_card(''), @options)
    assert_failure response
    assert_equal 'Invalid ccNum', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match "Success", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match(/declined/, response.message)
    assert_match(/Insufficient funds/, response.message)
  end

  def test_invalid_login
    gateway = ProPayGateway.new(cert_str: 'bad_cert_str')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:cert_str], transcript)
  end
end
