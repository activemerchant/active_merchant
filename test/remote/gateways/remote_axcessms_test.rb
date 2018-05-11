require 'test_helper'

class RemoteAxcessmsTest < Test::Unit::TestCase
  def setup
    @gateway = AxcessmsGateway.new(fixtures(:axcessms))

    @amount = 1500
    @credit_card = credit_card("4200000000000000", month: 05, year: 2022)
    @declined_card = credit_card("4444444444444444", month: 05, year: 2022)
    @mode = "CONNECTOR_TEST"

    @options = {
      order_id: generate_unique_id,
      email: "customer@example.com",
      description: "Order Number #{Time.now.to_f.divmod(2473)[1]}",
      ip: "0.0.0.0",
      mode: @mode,
      billing_address: address
    }
  end

  def test_successful_authorization
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_match %r{Successful Processing - Request successfully processed}, auth.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_match %r{Successful Processing - Request successfully processed}, auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, {mode: @mode})
    assert_success capture, "Capture failed"
    assert_match %r{Successful Processing - Request successfully processed}, capture.message
  end

  def test_successful_authorize_and_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_match %r{Successful Processing - Request successfully processed}, auth.message

    assert capture = @gateway.capture(@amount-30, auth.authorization, {mode: @mode})
    assert_success capture, "Capture failed"
    assert_match %r{Successful Processing - Request successfully processed}, capture.message
  end

  def test_successful_authorize_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_match %r{Successful Processing - Request successfully processed}, auth.message

    assert void = @gateway.void(auth.authorization, {mode: @mode})
    assert_success void, "Void failed"
    assert_match %r{Successful Processing - Request successfully processed}, void.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Successful Processing - Request successfully processed}, response.message
  end

  def test_successful_purchase_with_minimal_options
    response = @gateway.purchase(@amount, @credit_card, billing_address: address)
    assert_success response
    assert_match %r{Successful Processing - Request successfully processed}, response.message
  end

  def test_successful_reference_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_match %r{Successful Processing - Request successfully processed}, purchase.message

    repeat_purchase = @gateway.purchase(@amount, purchase.authorization, @options)
    assert_success repeat_purchase
    assert_match %r{Successful Processing - Request successfully processed}, repeat_purchase.message
  end

  def test_successful_purchase_and_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase, "Purchase failed"
    assert_match %r{Successful Processing - Request successfully processed}, purchase.message

    assert refund = @gateway.refund(@amount, purchase.authorization, {mode: @mode})
    assert_success refund, "Refund failed"
    assert_match %r{Successful Processing - Request successfully processed}, refund.message
  end

  def test_successful_purchase_and_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase, "Purchase failed"
    assert_match %r{Successful Processing - Request successfully processed}, purchase.message

    assert refund = @gateway.refund(@amount-50, purchase.authorization, {mode: @mode})
    assert_success refund, "Refund failed"
    assert_match %r{Successful Processing - Request successfully processed}, refund.message
  end

  # Failure tested

  def test_utf8_description_does_not_blow_up
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(description: "Habitación"))
    assert_success response
    assert_match %r{Successful Processing - Request successfully processed}, response.message
  end

  def test_failed_capture
    assert capture = @gateway.capture(@amount, "invalid authorization")
    assert_failure capture
    assert_match %r{Reference Error - capture}, capture.message
  end

  def test_failed_bigger_capture_then_authorised
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"

    assert capture = @gateway.capture(@amount+30, auth.authorization, {mode: @mode})
    assert_failure capture, "Capture failed"
    assert_match %r{PA value exceeded}, capture.message
  end

  def test_failed_authorize
    authorize = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure authorize
    assert_match %r{invalid creditcard}, authorize.message
  end

  def test_failed_refund
    assert refund = @gateway.refund(@amount, "invalid authorization", {mode: @mode})
    assert_failure refund
    assert_match %r{Configuration Validation - Invalid payment data}, refund.message
  end

  def test_failed_void
    void = @gateway.void("invalid authorization", {mode: @mode})
    assert_failure void
    assert_match %r{Reference Error - reversal}, void.message
  end

  def test_unauthorized_capture
    assert response = @gateway.capture(@amount, "1234567890123456789012")
    assert_failure response
    assert_equal "Reference Error - capture needs at least one successful transaction of type (PA)", response.message
  end

  def test_unauthorized_purchase_by_reference
    assert response = @gateway.purchase(@amount, "1234567890123456789012")
    assert_failure response
    assert_equal "Reference Error - reference id not existing", response.message
  end

  def test_failed_purchase_by_card
    purchase = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure purchase
    assert_match %r{Account Validation - invalid creditcard}, purchase.message
  end

  def test_invalid_login
    credentials = fixtures(:axcessms).merge(password: "invalid")
    response = AxcessmsGateway.new(credentials).purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{success}i, response.message
    assert_success response.responses.last, "The void should succeed"
  end

  def test_failed_verify
    assert response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{invalid}i, response.message
  end
end
