require 'test_helper'

class RemoteSecureCoTest < Test::Unit::TestCase
  def setup
    @gateway = SecureCoGateway.new(fixtures(:secure_co))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4111111111111110')
    @options = {}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "3d-acquirer:The resource was successfully created.", response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "3d-acquirer:The resource was successfully created.", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Luhn Check failed on the credit card number.  Please check your input and try again.  ", response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "3d-acquirer:The resource was successfully created.", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Luhn Check failed on the credit card number.  Please check your input and try again.  ", response.message
  end

  def test_successful_store_and_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r{\d{16}}, response.authorization

    response = @gateway.purchase(@amount, response.authorization)
    assert_success response
    assert_equal "3d-acquirer:The resource was successfully created.", response.message
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_equal "Luhn Check failed on the credit card number.  Please check your input and try again.  ", response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert_raises ArgumentError do
      @gateway.capture(@amount, '')
    end
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '3d-acquirer:The resource was successfully created.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    assert_raises ArgumentError do
      @gateway.refund(@amount, '')
    end
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '3d-acquirer:The resource was successfully created.', void.message
  end

  def test_failed_void
    assert_raises ArgumentError do
      @gateway.void('')
    end
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "3d-acquirer:The resource was successfully created.", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Luhn Check failed on the credit card number.  Please check your input and try again.  ", response.message
  end

  def test_invalid_login
    exception = assert_raises ActiveMerchant::ResponseError do
      gateway = SecureCoGateway.new(username: '', password: '', merchant_account_id: '')
      gateway.purchase(@amount, @credit_card, @options)
    end
    assert_equal '401', exception.response.code
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

end
