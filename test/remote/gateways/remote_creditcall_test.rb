require 'test_helper'

class RemoteCreditcallTest < Test::Unit::TestCase
  def setup
    @gateway = CreditcallGateway.new(fixtures(:creditcall))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal response.params['Zip'], 'notchecked'
    assert_equal response.params['Address'], 'notchecked'
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      manual_type: "cnp"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    @amount = 1001
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'ExpiredCard', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Succeeded', auth.message
  end

  def test_successful_authorize_with_zip_verification
    response = @gateway.authorize(@amount, @credit_card, @options.merge(verify_zip: 'true'))
    assert_success response
    assert_equal response.params['Zip'], 'matched'
    assert_equal response.params['Address'], 'notchecked'
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_with_address_verification
    response = @gateway.authorize(@amount, @credit_card, @options.merge(verify_address: 'true'))
    assert_success response
    assert_equal response.params['Zip'], 'notchecked'
    assert_equal response.params['Address'], 'matched'
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    @amount = 1001
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'ExpiredCard', response.message
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
    assert_equal 'CardEaseReferenceInvalid', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    assert refund = @gateway.refund(@amount, '')
    assert_failure refund
    assert_equal 'CardEaseReferenceInvalid', refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'CardEaseReferenceInvalid', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    @declined_card.number = ""
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{PAN Must be >= 13 Digits}, response.message
  end

  def test_invalid_login
    gateway = CreditcallGateway.new(terminal_id: '', transaction_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid TerminalID - Must be 8 digit number}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:transaction_key], transcript)

  end
end
