require 'test_helper'

class RemoteCardprocessTest < Test::Unit::TestCase
  def setup
    @gateway = CardprocessGateway.new(fixtures(:cardprocess))

    @amount = 100
    @credit_card = credit_card('4200000000000000')
    @credit_card_3ds = credit_card('4711100000000000')

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{^Request successfully processed}, response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_match %r{^Request successfully processed}, response.message
  end

  def test_failed_purchase
    bad_credit_card = credit_card('4200000000000001')
    response = @gateway.purchase(@amount, bad_credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
    assert_equal 'invalid creditcard, bank account number or bank name', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_match %r{^Request successfully processed}, capture.message
  end

  def test_failed_authorize
    @gateway.instance_variable_set(:@test_options, {'customParameters[forceResultCode]' => '800.100.151'})
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'transaction declined (invalid card)', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '12345678123456781234567812345678')
    assert_failure response
    assert_equal 'capture needs at least one successful transaction of type (PA)', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_match %r{^Request successfully processed}, refund.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{^Request successfully processed}, response.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'invalid or missing parameter', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_match %r{^Request successfully processed}, void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'invalid or missing parameter', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{^Request successfully processed}, response.message
  end

  def test_failed_verify
    @gateway.instance_variable_set(:@test_options, {'customParameters[forceResultCode]' => '600.200.100'})
    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_match %r{invalid Payment Method}, response.message
  end

  def test_invalid_login
    gateway = CardprocessGateway.new(user_id: '00000000000000000000000000000000', password: 'qwerty', entity_id: '00000000000000000000000000000000')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'invalid authentication information', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:entity_id], transcript)
  end
end
