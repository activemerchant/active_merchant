require 'test_helper'

class RemotePaymillTest < Test::Unit::TestCase
  def setup
    params = fixtures(:paymill)
    @gateway = PaymillGateway.new(public_key: params[:public_key], private_key: params[:private_key])
    @amount = 100
    @credit_card = credit_card('5500000000000004')
    @options = {
        :email => 'Longbob.Longse@example.com'
    }
    @declined_card = credit_card('5105105105105100', month: 5, year: 2020)

    uri = URI.parse("https://test-token.paymill.com?transaction.mode=CONNECTOR_TEST&channel.id=#{params[:public_key]}&jsonPFunction=paymilljstests&account.number=4111111111111111&account.expiry.month=12&account.expiry.year=2018&account.verification=123&account.holder=John%20Rambo&presentation.amount3D=#{@amount}&presentation.currency3D=EUR")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(params[:private_key], '')
    response = https.request(request)
    @token = response.body.match('tok_[a-z|0-9]+')[0]
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Operation successful', response.message
  end

  def test_successful_purchase_with_token
    assert response = @gateway.purchase(@amount, @token)
    assert_success response
    assert_equal 'Operation successful', response.message
  end

  def test_failed_store_card_attempting_purchase
    @credit_card.number = ''
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '[account.number] This field is missing.', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Card declined', response.message
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Operation successful', response.message
    assert response.authorization

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
    assert_equal 'Operation successful', capture_response.message
  end

  def test_successful_authorize_and_capture_with_token
    assert response = @gateway.authorize(@amount, @token, @options)
    assert_success response
    assert_equal 'Operation successful', response.message
    assert response.authorization

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
    assert_equal 'Operation successful', capture_response.message
  end

  def test_successful_authorize_with_token
    assert response = @gateway.authorize(@amount, @token, @options)
    assert_success response
    assert_equal 'Operation successful', response.message
    assert response.authorization
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Preauthorisation failed', response.message
  end

  def test_failed_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_failure capture_response
    assert_equal 'Transaction duplicate', capture_response.message
  end

  def test_successful_authorize_and_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Operation successful', response.message
    assert response.authorization

    assert void_response = @gateway.void(response.authorization)
    assert_success void_response
    assert_equal 'Transaction approved.', void_response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Operation successful', refund.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    assert refund = @gateway.refund(300, response.authorization)
    assert_failure refund
    assert_equal 'Amount to high', refund.message
  end

  def test_invalid_login
    gateway = PaymillGateway.new(public_key: fixtures(:paymill)[:public_key], private_key: "SomeBogusValue")
    response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Access Denied', response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card)
    assert_success store
    assert_not_nil store.authorization

    purchase = @gateway.purchase(@amount, store.authorization)
    assert_success purchase
  end

  def test_failed_store_with_invalid_card
    @credit_card.number = ''
    assert response = @gateway.store(@credit_card)
    assert_failure response
    assert_equal '[account.number] This field is missing.', response.message
  end

  def test_successful_store_and_authorize
    store = @gateway.store(@credit_card)
    assert_success store
    assert_not_nil store.authorization

    authorize = @gateway.authorize(@amount, store.authorization)
    assert_success authorize
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = PaymillGateway.new(public_key: "unknown_key", private_key: "unknown_key")
    assert !gateway.verify_credentials
  end

end
