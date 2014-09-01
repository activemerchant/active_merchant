require_relative '../../test_helper'

class RemoteAxcessmsTest < Test::Unit::TestCase

  SUCCESS_MESSAGES = {
    "CONNECTOR_TEST" => "Successful Processing - Request successfully processed in 'Merchant in Connector Test Mode'",
    "INTEGRATOR_TEST" => "Successful Processing - Request successfully processed in 'Merchant in Integrator Test Mode'"
  }

  def setup
    @gateway = AxcessmsGateway.new(fixtures(:axcessms))

    @amount = 150
    @credit_card = credit_card("4200000000000000", month: 05, year: 2022)
    @declined_card = credit_card("4444444444444444", month: 05, year: 2022)
    @mode = "CONNECTOR_TEST"

    @options = {
      order_id: generate_unique_id,
      email: "customer@example.com",
      description: "Order Number #{Time.now.to_f.divmod(2473)[1]}",
      ip: "0.0.0.0",
      mode: @mode,
      billing_address: {
        :address1 => "Leopoldstr. 1",
        :zip => "80798",
        :city => "Munich",
        :state => "BY",
        :country => "DE"
      }
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal SUCCESS_MESSAGES[@mode], response.message
  end

  def test_successful_purchase_by_reference
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    repeat_purchase = @gateway.purchase(@amount, purchase.authorization, @options)
    assert_success repeat_purchase
    assert_equal SUCCESS_MESSAGES[@mode], repeat_purchase.message
  end

  def test_failed_purchase_by_card
    purchase = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure purchase
    assert_match %r{Account Validation - invalid creditcard}, purchase.message
  end

  def test_failed_purchase_by_reference
    purchase = @gateway.purchase(@amount, "invalid reference", @options)
    assert_failure purchase
    assert_equal "Reference Error - reference id not existing", purchase.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, {mode: @mode})
    assert_success capture, "Capture failed"
    assert_equal SUCCESS_MESSAGES[@mode], capture.message
  end

  def test_successful_authorize_and_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    assert capture = @gateway.capture(@amount-30, auth.authorization, {mode: @mode})
    assert_success capture, "Capture failed"
    assert_equal SUCCESS_MESSAGES[@mode], capture.message
  end

  def test_successful_authorize_and_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "Authorize failed"
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    assert void = @gateway.void(auth.authorization, {mode: @mode})
    assert_success void, "Void failed"
    assert_equal SUCCESS_MESSAGES[@mode], void.message
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

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase, "Purchase failed"
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    assert refund = @gateway.refund(@amount, purchase.authorization, {mode: @mode})
    assert_success refund, "Refund failed"
    assert_equal SUCCESS_MESSAGES[@mode], refund.message
  end

  def test_successful_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase, "Purchase failed"
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    assert refund = @gateway.refund(@amount-50, purchase.authorization, {mode: @mode})
    assert_success refund, "Refund failed"
    assert_equal SUCCESS_MESSAGES[@mode], refund.message
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

  def test_invalid_login
    credentials = fixtures(:axcessms).merge(password: "invalid")
    response = AxcessmsGateway.new(credentials).purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end