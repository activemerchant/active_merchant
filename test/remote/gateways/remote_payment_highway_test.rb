require 'test_helper'

class RemotePaymentHighwayTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentHighwayGateway.new(fixtures(:payment_highway))

    @amount = 1000
    @credit_card = credit_card('4153013999700024', month: 11, year: 2017, verification_value: "024")
    @declined_card = credit_card('4153013999700156', month: 11, year: 2017, verification_value: "156")
    @stolen_card = credit_card('4153013999700289', month: 11, year: 2017, verification_value: "289")
    @disabled_online_payments_card = credit_card('4920101111111113', month: 11, year: 2017, verification_value: "113")

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Request successful.', response.message
  end

  def test_successful_order_status
    options = {
      order_id: SecureRandom.uuid
    }

    @gateway.purchase(@amount, @credit_card, options)
    response = @gateway.order_status(options[:order_id])
    assert_success response
    assert response.params["transactions"].size == 1
  end

  def test_successful_transaction_status
    options = {
      order_id: SecureRandom.uuid
    }

    purchase = @gateway.purchase(@amount, @credit_card, options)
    response = @gateway.transaction_status(purchase.authorization)
    assert_success response
    assert response.params["transaction"]["status"]["state"] == "ok"
  end


  def test_declined_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_stolen_purchase
    response = @gateway.purchase(@amount, @stolen_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_disabled_online_payment_card_purchase
    response = @gateway.purchase(@amount, @disabled_online_payments_card, @options)
    assert_failure response
    assert_equal 'Authorization failed', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @credit_card)
    assert_success refund
    assert_equal 'Request successful.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount / 2, purchase.authorization, @credit_card)
    assert_success refund
    assert_equal 'Request successful.', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount*(-1), purchase.authorization, @credit_card)
    assert_failure response
    assert_equal 'Invalid input. Detailed information is in the message field.', response.message
  end
end
