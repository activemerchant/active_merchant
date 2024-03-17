require 'test_helper'

class RemoteXpayTest < Test::Unit::TestCase
  def setup
    @gateway = XpayGateway.new(fixtures(:xpay))
    @amount = 100
    @credit_card = credit_card(
      '5186151650005008',
      month: 12,
      year: 2026,
      verification_value: '123',
      brand: 'master'
    )

    @options = {
      order_id: SecureRandom.alphanumeric(10),
      email: 'example@example.com',
      billing_address: address,
      order: {
        currency: 'EUR',
        amount: @amount
      }
    }
  end

  ## Test for authorization, capture, purchase and refund requires set up through 3ds
  ## The only test that does not depend on a 3ds flow is verify
  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'EXECUTED', response.message
  end

  def test_successful_preauth
    response = @gateway.preauth(@amount, @credit_card, @options)
    assert_success response
    assert_match 'PENDING', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'GW0001', response.error_code
    assert_match 'An internal error occurred', response.message
  end
end
