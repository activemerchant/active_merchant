require 'test_helper'

class CashnetTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = CashnetGateway.new(fixtures(:cashnet))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
end