require 'test_helper'

class RemoteS5Test < Test::Unit::TestCase
  def setup
    @gateway = S5Gateway.new(fixtures(:s5))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
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

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_successful_purchase_sans_cvv
    @options[:recurring] = true
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_successful_purchase_with_utf_character
    card = credit_card('4000100011112224', last_name: 'Wåhlin')
    response = @gateway.purchase(@amount, card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_successful_purchase_without_address
    response = @gateway.purchase(@amount, @credit_card, {})
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_failed_purchase
    @options[:memo] = "800.100.151"
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'transaction declined (invalid card)', response.message
  end

  def test_failed_purchase_sans_cvv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{empty CVV .* not allowed}, response.message
  end

  def test_successful_authorize_without_address
    auth = @gateway.authorize(@amount, @credit_card, {})
    assert_success auth
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    @options[:memo] = "100.400.080"
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(100, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_failed_verify
    @options[:memo] = "100.400.080"
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{authorization failure}, response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_match %r{Request successfully processed}, response.message
  end

  def test_failed_store
    credit_card = credit_card('4111')
    response = @gateway.store(credit_card, @options)
    assert_failure response
    assert_match %r{invalid creditcard}, response.message
  end

  def test_invalid_login
    gateway = S5Gateway.new(
      sender: '',
      channel: '',
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
