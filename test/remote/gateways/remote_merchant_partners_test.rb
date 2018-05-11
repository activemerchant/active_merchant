require "test_helper"

class RemoteMerchantPartnersTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantPartnersGateway.new(fixtures(:merchant_partners))

    @amount = 100
    @credit_card = credit_card("4003000123456781")
    @declined_card = credit_card("4003000123456782")

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Store Purchase"
    }
  end

  def test_invalid_login
    gateway = MerchantPartnersGateway.new(
      account_id: "TEST0",
      merchant_pin: "1"
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Invalid account/, response.message)
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Invalid account/, response.message)
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "BAD")
    assert_failure response
    assert_equal "Missing account number", response.message
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "Invalid acct type", response.message
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_equal "Missing account number", response.message
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
    assert_match(/Invalid account/, response.message)
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match(/Invalid account/, response.message)
    assert response.params["result"].start_with?("DECLINED")
  end

  def test_successful_store_and_purchase
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message

    purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
    assert_equal "Succeeded", purchase.message
  end

  def test_successful_store_and_credit
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message

    credit = @gateway.credit(@amount, response.authorization, @options)
    assert_success credit
    assert_equal "Succeeded", credit.message
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response

    # Test gateway bombs w/ live-transaction error so can't test
    # assert_equal "Invalid account number", response.message
    # assert_equal "", response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:merchant_pin], clean_transcript)
  end
end
