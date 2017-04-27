require "test_helper"

class RemotePayuLatamTest < Test::Unit::TestCase
  def setup
    @gateway = PayuLatamGateway.new(fixtures(:payu_latam))

    @amount = 4000
    @credit_card = credit_card("4097440000000004", verification_value: "444", first_name: "APPROVED", last_name: "")
    @declined_card = credit_card("4097440000000004", verification_value: "333", first_name: "REJECTED", last_name: "")
    @pending_card = credit_card("4097440000000004", verification_value: "222", first_name: "PENDING", last_name: "")

    @options = {
      currency: "ARS",
      order_id: generate_unique_id,
      description: "Active Merchant Transaction",
      installments_number: 1,
      billing_address: address(
        address1: "Viamonte",
        address2: "1366",
        city: "Plata",
        state: "Buenos Aires",
        country: "AR",
        zip: "64000",
        phone: "7563126"
      )
    }
  end

  # At the time of writing this test, gateway sandbox
  # supports auth and purchase transactions only

  def test_invalid_login
    gateway = PayuLatamGateway.new(merchant_id: "", account_id: "", api_login: "U", api_key: "U")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_successful_purchase_brazil
    gateway = PayuLatamGateway.new(fixtures(:payu_latam).update(:account_id => "512327"))

    options_brazil = {
      currency: "BRL",
      billing_address: address(
        address1: "Calle 100",
        address2: "BL4",
        city: "Sao Paulo",
        state: "SP",
        country: "BR",
        zip: "09210710",
        phone: "(11)756312633"
      ),
      shipping_address: address(
        address1: "Calle 200",
        address2: "N107",
        city: "Sao Paulo",
        state: "SP",
        country: "BR",
        zip: "01019-030",
        phone: "(11)756312633"
      )
    }

    response = gateway.purchase(@amount, @credit_card, @options.update(options_brazil))
    assert_success response
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "ANTIFRAUD_REJECTED", response.message
    assert_equal "DECLINED", response.params["transactionResponse"]["state"]
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_match %r(^\d+\|(\w|-)+$), response.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @pending_card, @options)
    assert_failure response
    assert_equal "PENDING_TRANSACTION_REVIEW", response.message
    assert_equal "PENDING", response.params["transactionResponse"]["state"]
  end

  def test_well_formed_refund_fails_as_expected
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_equal "The payment plan id cannot be empty", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_match /property: parentTransactionId, message: must not be null/, response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "APPROVED", void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_match /property: parentTransactionId, message: must not be null/, response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'APPROVED', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match /must not be null/, response.message
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = PayuLatamGateway.new(merchant_id: "X", account_id: "512322", api_login: "X", api_key: "X")
    assert !gateway.verify_credentials
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:api_key], clean_transcript)
  end
end
