require 'test_helper'

class RemoteRedsysTest < Test::Unit::TestCase
  def setup
    @gateway = RedsysGateway.new(fixtures(:redsys))
    @credit_card = credit_card('4548812049400004')
    @declined_card = credit_card
    @options = {
      order_id: generate_order_id,
      description: 'Test Description'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(100, @credit_card, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_purchase_with_invalid_order_id
    response = @gateway.purchase(100, @credit_card, order_id: "a%4#{generate_order_id}")
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_successful_purchase_using_vault_id
    response = @gateway.purchase(100, @credit_card, @options.merge(store: true))
    assert_success response
    assert_equal "Transaction Approved", response.message

    credit_card_token = response.params["ds_merchant_identifier"]
    assert_not_nil credit_card_token

    @options[:order_id] = generate_order_id
    response = @gateway.purchase(100, credit_card_token, @options)
    assert_success response
    assert_equal "Transaction Approved", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(100, @declined_card, @options)
    assert_failure response
    assert_equal "SIS0093 ERROR", response.message
  end

  def test_purchase_and_refund
    purchase = @gateway.purchase(100, @credit_card, @options)
    assert_success purchase
    refund = @gateway.refund(100, purchase.authorization)
    assert_success refund
  end

  # Multiple currencies are not supported in test, but should at least fail.
  def test_purchase_and_refund_with_currency
    response = @gateway.purchase(600, @credit_card, @options.merge(:currency => 'PEN'))
    assert_failure response
    assert_equal "SIS0027 ERROR", response.message
  end

  def test_successful_authorise_and_capture
    authorize = @gateway.authorize(100, @credit_card, @options)
    assert_success authorize
    assert_equal "Transaction Approved", authorize.message
    assert_not_nil authorize.authorization

    capture = @gateway.capture(100, authorize.authorization)
    assert_success capture
    assert_match /Refund.*approved/, capture.message
  end

  def test_successful_authorise_using_vault_id
    authorize = @gateway.authorize(100, @credit_card, @options.merge(store: true))
    assert_success authorize
    assert_equal "Transaction Approved", authorize.message
    assert_not_nil authorize.authorization

    credit_card_token = authorize.params["ds_merchant_identifier"]
    assert_not_nil credit_card_token

    @options[:order_id] = generate_order_id
    authorize = @gateway.authorize(100, credit_card_token, @options)
    assert_success authorize
    assert_equal "Transaction Approved", authorize.message
    assert_not_nil authorize.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(100, @declined_card, @options)
    assert_failure response
    assert_equal "SIS0093 ERROR", response.message
  end

  def test_successful_void
    authorize = @gateway.authorize(100, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
    assert_equal "100", void.params["ds_amount"]
    assert_equal "Cancellation Accepted", void.message
  end

  def test_failed_void
    authorize = @gateway.authorize(100, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void

    another_void = @gateway.void(authorize.authorization)
    assert_failure another_void
    assert_equal "SIS0222 ERROR", another_void.message
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Transaction Approved", response.message
    assert_success response.responses.last, "The void should succeed"
    assert_equal "Cancellation Accepted", response.responses.last.message
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "SIS0093 ERROR", response.message
  end

  private

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
