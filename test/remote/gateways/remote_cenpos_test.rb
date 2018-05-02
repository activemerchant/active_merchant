require "test_helper"

class RemoteCenposTest < Test::Unit::TestCase
  def setup
    @gateway = CenposGateway.new(fixtures(:cenpos))

    @amount = SecureRandom.random_number(10000)
    @credit_card = credit_card("4111111111111111", month: 02, year: 18, verification_value: 999)
    @declined_card = credit_card("4000300011112220")
    @invalid_card = credit_card("9999999999999999")

    @options = {
      order_id: SecureRandom.random_number(1000000),
      billing_address: address
    }
  end

  def test_invalid_login
    gateway = CenposGateway.new(
      merchant_id: "",
      password: "",
      user_id: ""
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "See transcript for detailed error description.", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "M", response.cvv_result["code"]
  end

  def test_successful_purchase_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "D", response.avs_result["code"]
  end

  def test_successful_purchase_with_invoice_detail
    response = @gateway.purchase(@amount, @credit_card, @options.merge(invoice_detail: "<xml><description/></xml>"))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_customer_code
    response = @gateway.purchase(@amount, @credit_card, @options.merge(customer_code: "3214"))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_currency
    response = @gateway.purchase(@amount, @credit_card, @options.merge(currency: "EUR"))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_failed_purchase_cvv_result
    response = @gateway.purchase(@amount, @declined_card, @options)
    %w(code message).each do |key|
      assert_equal nil, response.cvv_result[key]
    end
  end

  def test_failed_purchase_avs_result
    response = @gateway.purchase(@amount, @declined_card, @options)
    %w(code message).each do |key|
      assert_equal nil, response.avs_result[key]
    end
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+\|.+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_failed_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message

    capture = @gateway.capture(@amount, response.authorization)
    capture = @gateway.capture(@amount, response.authorization)
    assert_failure capture
    assert_equal "Duplicated transaction", capture.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_void_can_receive_order_id
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization, order_id: SecureRandom.random_number(1000000))
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    void = @gateway.void(response.authorization)
    assert_failure void
    assert_equal "Original Transaction not found", void.message
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
    assert_equal "See transcript for detailed error description.", response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal "Invalid card number", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Decline transaction", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
