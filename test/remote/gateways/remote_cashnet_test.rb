require 'test_helper'

class CashnetTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = CashnetGateway.new(fixtures(:cashnet))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address
    }
  end

  def test_successful_purchase_and_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
    assert response.authorization
    assert response = @gateway.purchase(@amount, response.authorization, {})
    assert_success response
    assert response.test?
    assert_equal 'Success', response.message
  end
end