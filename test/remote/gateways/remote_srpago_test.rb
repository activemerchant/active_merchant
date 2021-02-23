require 'test_helper'

class RemoteSrpagoTest < Test::Unit::TestCase
  def setup
    @gateway = SrpagoGateway.new(fixtures(:srpago))

    @amount = 100.12
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4242424242424241')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
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
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase_declined
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "51", response.error_code 
  end
  
  def test_failed_purchase_invalid
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal "14", response.error_code 
  end

  def test_successful_void
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_failed_void_with_missing_auth
    response = @gateway.void('')
    assert_failure response
    assert_equal "El servicio no existe", response.message
  end
  
  def test_failed_void_with_bogus_auth
    response = @gateway.void('a')
    assert_failure response
    assert_equal "InvalidTransactionException", response.error_code
  end
  
  def test_failed_void
    response = @gateway.void("NDcxNjc2")
    assert_failure response
    assert_equal "InvalidAuthCodeException", response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Success}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{No se pudo procesar el cobro}, response.message
  end

  def test_invalid_login
    gateway = SrpagoGateway.new(apì_key: 'WRONG_KEY', api_secret: 'WRONG_PASS')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{El formato de la clave de apliacion no tiene el formato requerido}, response.message || (assert_match %r{El formato de la clave de apliacion no tiene el formato requerido}, response.message)
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
