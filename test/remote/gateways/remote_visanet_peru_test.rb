require "test_helper"

class RemoteVisanetPeruTest < Test::Unit::TestCase
  def setup
    @gateway = VisanetPeruGateway.new(fixtures(:visanet_peru))

    @amount = 100
    @credit_card = credit_card("4500340090000016", verification_value: "377")
    @declined_card = credit_card("4111111111111111")

    @options = {
      billing_address: address,
      order_id: generate_unique_id,
      email: "visanetperutest@mailinator.com"
    }
  end

  def test_invalid_login
    gateway = VisanetPeruGateway.new(access_key_id: "", secret_access_key: "", merchant_id: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert response.authorization
    assert_equal @options[:order_id], response.params["externalTransactionId"]
    assert response.test?
  end

  def test_successful_purchase_with_merchant_define_data
    options = @options.merge(merchant_define_data: { field3: "movil", field91: "101266802", field92: "TheMerchant" })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "OK", response.message
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "OK", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "Operacion Denegada.", response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert response.authorization
    assert_equal @options[:order_id], response.params["externalTransactionId"]
    assert_equal "1.00", response.params["data"]["IMP_AUTORIZADO"]

    capture = @gateway.capture(response.authorization, @options)
    assert_success capture
    assert_equal "OK", capture.message
    assert capture.authorization
    assert_equal @options[:order_id], capture.params["externalTransactionId"]
  end

  def test_successful_authorize_fractional_amount
    amount = 199
    response = @gateway.authorize(amount, @credit_card)
    assert_success response
    assert_equal "OK", response.message
    assert_equal "1.99", response.params["data"]["IMP_AUTORIZADO"]
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "Operacion Denegada.", response.message

    @options[:email] = "cybersource@reject.com"
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "El pedido ha sido rechazado por Decision Manager", response.message
  end

  def test_failed_capture
    response = @gateway.capture("900000044")
    assert_failure response
    assert_match /NUMORDEN 900000044 no se encuentra registrado/, response.message
    assert_equal 400, response.error_code
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "OK", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, "900000044" )
    assert_failure response
    assert_match /NUMORDEN 900000044 no se encuentra registrado/, response.message
    assert_equal 400, response.error_code
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message
  end

  def test_failed_void
    response = @gateway.void("900000044")
    assert_failure response
    assert_match /NUMORDEN no se encuentra registrado/, response.message
    assert_equal 400, response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert_equal @options[:order_id], response.params["externalTransactionId"]
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "Operacion Denegada.", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:secret_access_key], clean_transcript)
  end
end
