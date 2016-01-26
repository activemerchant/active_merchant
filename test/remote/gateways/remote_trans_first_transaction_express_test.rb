require "test_helper"

class RemoteTransFirstTransactionExpressTest < Test::Unit::TestCase
  def setup
    @gateway = TransFirstTransactionExpressGateway.new(fixtures(:trans_first_transaction_express))

    @amount = 100
    @declined_amount = 21
    @partial_amount = 1110
    @credit_card = credit_card("4485896261017708")

    billing_address = address({
      address1: "450 Main",
      address2: "Suite 100",
      city: "Broomfield",
      state: "CO",
      zip: "85284",
      phone: "(333) 444-5555",
    })

    @options = {
      order_id: generate_unique_id,
      company_name: "Acme",
      title: "QA Manager",
      billing_address: billing_address,
      shipping_address: billing_address,
      email: "example@example.com",
      description: "Store Purchase"
    }
  end

  def test_invalid_login
    gateway = TransFirstTransactionExpressGateway.new(gateway_id: "", reg_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_partial_purchase
    response = @gateway.purchase(@partial_amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match /0*555$/, response.params["amt"]
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.params["rspCode"]
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^authorize\|\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal "Not sufficient funds", response.message
    assert_equal "51", response.error_code
  end

  def test_failed_capture
    authorize = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure authorize

    response = @gateway.capture(@amount, authorize.authorization)
    assert_failure response
    assert_equal "Invalid transaction", response.message
    assert_equal "12", response.error_code
  end

  def test_successful_purchase_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_authorization_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_capture_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    capture = @gateway.capture(@amount, authorize.authorization)
    assert_success capture

    void = @gateway.void(capture.authorization, void_type: :void_capture)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "50011", response.error_code
  end

  # gateway does not settle fast enough to test refunds
  # def test_successful_refund
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success response

  #   refund = @gateway.refund(@amount, response.authorization)
  #   assert_success refund
  #   assert_equal "Succeeded", refund.message
  # end

  def test_helpful_message_when_refunding_unsettled_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization)

    assert_failure refund
    assert_equal "Invalid transaction. Declined Post – Credit linked to unextracted settle transaction", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "50011", response.error_code
  end

  # Credit is only supported with specific approval from Transaction Express
  # def test_successful_credit
  #   response = @gateway.credit(@amount, @credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  # end

  def test_failed_credit
    response = @gateway.credit(0, @credit_card, @options)
    assert_failure response
    assert_equal "51334", response.error_code
    assert_equal "Validation Error", response.message
  end

  def test_successful_verify
    visa = credit_card("4485896261017708")
    amex = credit_card("371449635392376", verification_value: 1234)
    mastercard = credit_card("5499740000000057")
    discover = credit_card("6011000991001201")

    [visa, amex, mastercard, discover].each do |credit_card|
      response = @gateway.verify(credit_card, @options)
      assert_success response
      assert_match "Succeeded", response.message
    end
  end

  def test_failed_verify
    response = @gateway.verify(credit_card(""), @options)
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "50011", response.error_code
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.authorization
  end

  def test_successful_authorize_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_authorize_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.authorize(@declined_amount, response.authorization, @options)
    assert_failure response
    assert_match "Not sufficient funds", response.message
  end

  def test_successful_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@amount, response.authorization, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_purchase_using_stored_card
    assert response = @gateway.store(@credit_card)
    assert_success response

    response = @gateway.purchase(@declined_amount, response.authorization, @options)
    assert_failure response
    assert_match "Not sufficient funds", response.message
  end

  def test_failed_store
    response = @gateway.store(credit_card("123"), @options)
    assert_failure response
    assert_equal "Validation Failure", response.message
    assert_equal "50011", response.error_code
  end

  # def test_dump_transcript
  #   skip("Transcript scrubbing for this gateway has been tested.")
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:gateway_id], clean_transcript)
    assert_scrubbed(@gateway.options[:reg_key], clean_transcript)
  end
end
