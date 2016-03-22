require "test_helper"

class RemoteVisanetPeruTest < Test::Unit::TestCase
  def setup
    @gateway = VisanetPeruGateway.new(fixtures(:visanet_peru))

    @amount = 100
    @credit_card = credit_card("4500340090000016", verification_value: "377")
    @declined_card = credit_card("4111111111111111")

    @options = {
      # Visanet Peru expects a 9-digit numeric purchaseNumber
      purchase_number: rand(100000000 .. 1000000000).to_s,
      order_id: (SecureRandom.random_number() * (10 ** 9)).floor.to_s,
      billing_address: address,
      email: "visanetperutest@mailinator.com",
      merchant_id: "101266802",
      device_fingerprint_id: "deadbeef",
      merchant_define_data: {
        field3: "movil",  # Channel
        field91: "101266802", # Merchant Code / Merchant Id
        field92: "Cabify" # Merchant Name
      }
    }
  end

  def test_invalid_login
    gateway = VisanetPeruGateway.new(access_key_id: "", secret_access_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
    assert_equal "deposit|" + @options[:merchant_id] + "|" + @options[:purchase_number], response.authorization
    assert response.test?
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
    assert_equal "authorize|" + @options[:merchant_id] + "|" + @options[:purchase_number], response.authorization

    capture = @gateway.capture(response.authorization, @options)
    assert_success capture
    assert_equal "OK", capture.message
    assert_equal "deposit|" + @options[:merchant_id] + "|" + @options[:purchase_number], capture.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 400, response.error_code

    @options[:email] = "cybersource@reject.com"
    @options[:purchase_number] = rand(100000000 .. 1000000000).to_s
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 400, response.error_code
    assert_equal "El pedido ha sido rechazado por Decision Manager", response.message
  end

  def test_failed_capture
    invalid_purchase_number = (SecureRandom.random_number() * (10 ** 9)).floor.to_s
    response = @gateway.capture("authorize" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
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

    @options[:purchase_number] = rand(100000000 .. 1000000000).to_s
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "OK", void.message
  end

  def test_failed_void
    invalid_purchase_number = (SecureRandom.random_number() * (10 ** 9)).floor.to_s
    response = @gateway.void("authorize" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ \"NUMORDEN no se encuentra registrado.\", \"No se ha realizado la anulacion del pedido\" ]", response.message
    assert_equal 400, response.error_code

    response = @gateway.void("deposit" + "|" + @options[:merchant_id] + "|" + invalid_purchase_number)
    assert_failure response
    assert_equal "[ \"NUMORDEN " + invalid_purchase_number + " no se encuentra registrado\", \"No se realizo la anulacion del deposito\" ]", response.message
    assert_equal 400, response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "OK", response.message
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
