require 'test_helper'

class RemoteSecurionPayTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /char_[a-zA-Z\d]+/
  TOKEN_ID_REGEX  = /tok_[a-zA-Z\d]+/

  def setup
    @gateway = SecurionPayGateway.new(fixtures(:securion_pay))

    @amount = 2000
    @refund_amount = 300
    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4916018475814056')
    @new_credit_card = credit_card('4012888888881881')
    @invalid_token = 'tok_invalid'

    @options = {
      description: 'ActiveMerchant test charge',
      email: 'foo@example.com'
    }
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r(^cust_\w+$), response.authorization
    assert_equal "customer", response.params["objectType"]
    assert_match %r(^card_\w+$), response.params["cards"][0]["id"]
    assert_equal "card", response.params["cards"][0]["objectType"]

    @options[:customer_id] = response.authorization
    response = @gateway.store(@new_credit_card, @options)
    assert_success response
    assert_match %r(^card_\w+$), response.params["card"]["id"]
    assert_equal @options[:customer_id], response.params["card"]["customerId"]

    response = @gateway.customer(@options)
    assert_success response
    assert_equal @options[:customer_id], response.params["id"]
    assert_equal "401288", response.params["cards"][0]["first6"]
    assert_equal "1881", response.params["cards"][0]["last4"]
    assert_equal "424242", response.params["cards"][1]["first6"]
    assert_equal "4242", response.params["cards"][1]["last4"]
  end

  # def test_dump_transcript
  #   skip("Transcript scrubbing for this gateway has been tested.")
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Transaction approved", response.message
    assert_equal "foo@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_unsuccessful_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{The card was declined for other reason.}, response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_authorization_and_capture
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]
    assert_equal @options[:description], authorization.params["description"]
    assert_equal @options[:email], authorization.params["metadata"]["email"]

    response = @gateway.capture(@amount, authorization.authorization)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'invalid_authorization_token')
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_successful_full_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund

    assert refund.params["refunded"]
    assert_equal 0, refund.params["amount"]
    assert_equal 1, refund.params["refunds"].size
    assert_equal @amount, refund.params["refunds"].map{|r| r["amount"]}.sum

    assert refund.authorization
  end

  def test_successful_partially_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    first_refund = @gateway.refund(@refund_amount, purchase.authorization)
    assert_success first_refund

    second_refund = @gateway.refund(@refund_amount, purchase.authorization)
    assert_success second_refund
    assert second_refund.params["refunded"]
    assert_equal @amount - 2 * @refund_amount, second_refund.params["amount"]
    assert_equal 2, second_refund.params["refunds"].size
    assert_equal 2 * @refund_amount, second_refund.params["refunds"].map{|r| r["amount"]}.sum
    assert second_refund.authorization
  end

  def test_unsuccessful_authorize_refund
    response = @gateway.refund(@amount, 'invalid_authorization_token')
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_unsuccessful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization

    refund = @gateway.refund(@amount + 1, purchase.authorization, @options)
    assert_failure refund
    assert_match %r{Invalid Refund data}, refund.message
  end

  def test_successful_void
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert !authorization.params["captured"]

    void = @gateway.void(authorization.authorization, @options)
    assert_success void
    assert void.params["refunded"]
    assert_equal 0, void.params["amount"]
    assert_equal 1, void.params["refunds"].size
    assert_equal @amount, void.params["refunds"].map{|r| r["amount"]}.sum
    assert void.authorization
  end

  def test_failed_void
    response = @gateway.void('invalid_authorization_token', @options)
    assert_failure response
    assert_match %r{Requested Charge does not exist}, response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction approved}, response.responses.last.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{The card was declined for other reason.}, response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.primary_response.error_code
  end

  def test_incorrect_number_for_purchase
    card = credit_card('4242424242424241')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_invalid_login
    gateway = SecurionPayGateway.new(secret_key: 'active_merchant_test')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match "Provided API key is invalid", response.message
  end

  def test_invalid_number_for_purchase
    card = credit_card('-1')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_invalid_expiry_month_for_purchase
    card = credit_card('4242424242424242', month: 16)
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_invalid_expiry_year_for_purchase
    card = credit_card('4242424242424242', year: 'xx')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_expiry_date], response.error_code
  end

  def test_expired_card_for_purchase
    card = credit_card('4916487051294548')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_invalid_cvc_for_purchase
    card = credit_card('4242424242424242', verification_value: -1)
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_incorrect_cvc_for_purchase
    card = credit_card('4024007134364842')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_cvc], response.error_code
  end

  def test_processing_error
    card = credit_card('4024007114166316')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_incorrect_zip
    card = credit_card('4929225021529113')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_zip], response.error_code
  end

  def test_card_declined
    card = credit_card('4916018475814056')
    response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end
end
