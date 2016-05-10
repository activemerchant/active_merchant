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
    assert_match %r(^deposit\|[0-9]{9}$), response.authorization
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
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert_match %r(^authorize\|[0-9]{9}$), response.authorization
    assert_equal @options[:order_id], response.params["externalTransactionId"]
    assert_equal "1.00", response.params["data"]["IMP_AUTORIZADO"]

    capture = @gateway.capture(response.authorization, @options)
    assert_success capture
    assert_equal "OK", capture.message
    assert_match %r(^deposit\|[0-9]{9}$), capture.authorization
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

    @options[:email] = "cybersource@reject.com"
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "El pedido ha sido rechazado por Decision Manager", response.message
  end

  def test_failed_capture
    invalid_purchase_number = (SecureRandom.random_number(900_000_000) + 100_000_000).to_s
    response = @gateway.capture("authorize" + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ \"NUMORDEN " + invalid_purchase_number + " no se encuentra registrado\", \"No se realizo el deposito\" ]", response.message
    assert_equal 400, response.error_code
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message
  end

  def test_failed_void
    invalid_purchase_number = (SecureRandom.random_number(900_000_000) + 100_000_000).to_s
    response = @gateway.void("authorize" + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ \"NUMORDEN no se encuentra registrado.\", \"No se ha realizado la anulacion del pedido\" ]", response.message
    assert_equal 400, response.error_code

    response = @gateway.void("deposit" + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ \"NUMORDEN " + invalid_purchase_number + " no se encuentra registrado\", \"No se realizo la anulacion del deposito\" ]", response.message
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
  end

  # def test_dump_transcript
  #   #skip("Transcript scrubbing for this gateway has been tested.")

  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

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
