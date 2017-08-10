require 'test_helper'

class RemoteIveriTest < Test::Unit::TestCase
  def setup
    @gateway = IveriGateway.new(fixtures(:iveri))

    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @bad_card = credit_card('2121212121212121')
    @timeout_card = credit_card('5454545454545454')
    @invalid_card = credit_card('1111222233334444')
    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '100', response.params['amount']
  end

  def test_successful_purchase_with_more_options
    options = {
      ip: "127.0.0.1",
      email: "joe@example.com",
      currency: 'ZAR'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_3ds_params
    options = {
      eci: "ThreeDSecure",
      xid: SecureRandom.hex(14),
      cavv: SecureRandom.hex(14)
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end


  def test_failed_purchase
    response = @gateway.purchase(@amount, @bad_card, @options)
    assert_failure response
    assert_includes ['Denied', 'Hot card', 'Please call'], response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @bad_card, @options)
    assert_failure response
    assert_includes ['Denied', 'Hot card', 'Please call'], response.message
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
    assert_equal 'Missing PAN', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
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
    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_match %r{Credit is not supported}, response.message
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
    assert_equal 'Missing OriginalMerchantTrace', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@bad_card, @options)
    assert_failure response
    assert_includes ['Denied', 'Hot card', 'Please call'], response.message
  end

  def test_successful_verify_credentials
    assert @gateway.verify_credentials
  end

  def test_failed_verify_credentials
    gateway = IveriGateway.new(app_id: '11111111-1111-1111-1111-111111111111', cert_id: '11111111-1111-1111-1111-111111111111')
    assert !gateway.verify_credentials
  end

  def test_invalid_login
    gateway = IveriGateway.new(app_id: '', cert_id: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'No CertificateID specified', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:cert_id], transcript)
  end

end
