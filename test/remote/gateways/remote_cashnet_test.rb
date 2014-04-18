require 'test_helper'

class CashnetTest < Test::Unit::TestCase
  def setup
    @gateway = CashnetGateway.new(fixtures(:cashnet))
    @amount = 100
    @credit_card = credit_card(
      "5454545454545454",
      month: 12,
      year: 2015
    )
    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.test?
    assert_equal 'Success', purchase.message
    assert purchase.authorization

    assert refund = @gateway.refund(@amount, purchase.authorization, {})
    assert_success refund
    assert refund.test?
    assert_equal 'Success', refund.message
  end
end
